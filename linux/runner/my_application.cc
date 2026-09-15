#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/xattr.h>
#include <unistd.h>
#ifndef RENAME_NOREPLACE
// renameat2 is a Linux system call. Its flag is a stable UAPI value, but some
// supported libc/header combinations expose the syscall number without this
// GNU-extension declaration.
#define RENAME_NOREPLACE (1U << 0)
#endif
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  FlMethodChannel* save_channel;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

namespace {

FlValue* save_result(const gchar* status, const gchar* message = nullptr,
                     const gchar* recovery_path = nullptr) {
  FlValue* result = fl_value_new_map();
  fl_value_set_string_take(result, "status", fl_value_new_string(status));
  if (message != nullptr) {
    fl_value_set_string_take(result, "message", fl_value_new_string(message));
  }
  if (recovery_path != nullptr) {
    fl_value_set_string_take(result, "recoveryPath",
                             fl_value_new_string(recovery_path));
  }
  return result;
}

bool regular_file(const gchar* path) {
  struct stat info;
  return lstat(path, &info) == 0 && S_ISREG(info.st_mode);
}

bool same_filesystem(const gchar* staged_path, const gchar* destination_path) {
  struct stat staged_info;
  struct stat directory_info;
  g_autofree gchar* parent = g_path_get_dirname(destination_path);
  return stat(staged_path, &staged_info) == 0 &&
         stat(parent, &directory_info) == 0 &&
         staged_info.st_dev == directory_info.st_dev;
}

enum class ExtendedMetadata { kNone, kPresent, kUnavailable };

ExtendedMetadata extended_metadata(const gchar* path) {
  const ssize_t size = llistxattr(path, nullptr, 0);
  if (size == 0) return ExtendedMetadata::kNone;
  if (size > 0) return ExtendedMetadata::kPresent;
  // A filesystem without xattr support cannot contain a POSIX ACL or another
  // xattr on this path. Other inspection failures are not safe to ignore.
  if (errno == ENOTSUP || errno == EOPNOTSUPP) {
    return ExtendedMetadata::kNone;
  }
  return ExtendedMetadata::kUnavailable;
}

int rename_no_replace(const gchar* staged_path, const gchar* destination_path) {
#ifdef SYS_renameat2
  return syscall(SYS_renameat2, AT_FDCWD, staged_path, AT_FDCWD,
                 destination_path, RENAME_NOREPLACE);
#else
  errno = ENOSYS;
  return -1;
#endif
}

gchar* backup_path(const gchar* destination_path, int attempt) {
  g_autofree gchar* parent = g_path_get_dirname(destination_path);
  return g_strdup_printf("%s/.mushagaeshi-save-backup-%d-%" G_GINT64_FORMAT "-%d.bak",
                         parent, getpid(), g_get_real_time(), attempt);
}

FlValue* install_saved_file(const gchar* staged_path,
                            const gchar* destination_path) {
  if (!regular_file(staged_path)) {
    return save_result("failed", "The staged file is not a regular file.");
  }
  if (!same_filesystem(staged_path, destination_path)) {
    return save_result("failed",
                       "Safe installation requires staging on the destination filesystem.");
  }

  struct stat destination_info;
  if (lstat(destination_path, &destination_info) != 0) {
    if (errno != ENOENT) {
      return save_result("failed", "Unable to inspect the destination file.");
    }
    // Linux renameat2 with RENAME_NOREPLACE makes a late-created destination a
    // safe failure. A plain rename would silently overwrite it.
    if (rename_no_replace(staged_path, destination_path) == 0) {
      return save_result("installed");
    }
    return save_result("ambiguous",
                       "The new destination could not be installed; the complete staged file was retained.",
                       staged_path);
  }
  if (!S_ISREG(destination_info.st_mode)) {
    return save_result("failed", "The destination is not a regular file.");
  }

  struct stat staged_info;
  if (lstat(staged_path, &staged_info) != 0 || !S_ISREG(staged_info.st_mode)) {
    return save_result("failed", "The staged file is not a regular file.");
  }
  // Renaming the staged file would otherwise silently replace these identity
  // attributes. Preserve neither elevated mode bits nor access metadata that
  // the backend cannot faithfully copy.
  if ((destination_info.st_mode & (S_ISUID | S_ISGID | S_ISVTX)) != 0) {
    return save_result("failed",
                       "Safe installation does not support files with special permission bits.");
  }
  if (destination_info.st_uid != staged_info.st_uid ||
      destination_info.st_gid != staged_info.st_gid) {
    return save_result("failed",
                       "Safe installation would change the file owner or group.");
  }
  const ExtendedMetadata destination_metadata = extended_metadata(destination_path);
  const ExtendedMetadata staged_metadata = extended_metadata(staged_path);
  if (destination_metadata == ExtendedMetadata::kUnavailable ||
      staged_metadata == ExtendedMetadata::kUnavailable) {
    return save_result("failed", "Unable to inspect file metadata safely.");
  }
  if (destination_metadata == ExtendedMetadata::kPresent ||
      staged_metadata == ExtendedMetadata::kPresent) {
    return save_result("failed",
                       "Safe installation does not support files with extended metadata.");
  }

  // The exclusive staging file is created with the process umask. Preserve
  // only ordinary read/write/execute permissions before the atomic namespace
  // replacement. Special bits were rejected above rather than re-granted.
  if (chmod(staged_path, destination_info.st_mode & 0777) != 0) {
    return save_result("failed", "Unable to preserve destination permissions.");
  }

  // Preserve a hard-link backup before the atomic replacement. This is cheap
  // on the required same filesystem and supplies a complete recovery copy if
  // rename reports a failure or the process is interrupted before cleanup.
  g_autofree gchar* backup = nullptr;
  for (int attempt = 0; attempt != 32; ++attempt) {
    backup = backup_path(destination_path, attempt);
    if (link(destination_path, backup) == 0) break;
    if (errno != EEXIST) {
      return save_result("failed", "Unable to create a recoverable destination backup.");
    }
    backup = nullptr;
  }
  if (backup == nullptr) {
    return save_result("failed", "Unable to reserve a recoverable destination backup.");
  }
  if (rename(staged_path, destination_path) == 0) {
    // The replacement completed. Retaining a backup after cleanup failure is
    // safer than attempting any copy-based cleanup.
    unlink(backup);
    return save_result("installed");
  }
  if (regular_file(staged_path)) {
    return save_result("ambiguous",
                       "Replacement did not complete; the staged file was retained for recovery.",
                       staged_path);
  }
  if (regular_file(backup)) {
    return save_result("ambiguous",
                       "Replacement did not complete; the backup file was retained for recovery.",
                       backup);
  }
  if (regular_file(destination_path)) {
    return save_result("ambiguous",
                       "Replacement reported a failure; inspect the destination before retrying.",
                       destination_path);
  }
  return save_result("failed",
                     "Replacement failed before a recoverable file could be identified.");
}

void save_method_call_handler(FlMethodChannel*, FlMethodCall* method_call,
                              gpointer) {
  if (g_strcmp0(fl_method_call_get_name(method_call), "installSavedFile") != 0) {
    fl_method_call_respond_not_implemented(method_call, nullptr);
    return;
  }
  FlValue* arguments = fl_method_call_get_args(method_call);
  if (arguments == nullptr || fl_value_get_type(arguments) != FL_VALUE_TYPE_MAP) {
    fl_method_call_respond_success(
        method_call, save_result("failed", "Invalid save installation arguments."), nullptr);
    return;
  }
  FlValue* staged = fl_value_lookup_string(arguments, "stagedPath");
  FlValue* destination = fl_value_lookup_string(arguments, "destinationPath");
  if (staged == nullptr || destination == nullptr ||
      fl_value_get_type(staged) != FL_VALUE_TYPE_STRING ||
      fl_value_get_type(destination) != FL_VALUE_TYPE_STRING) {
    fl_method_call_respond_success(
        method_call, save_result("failed", "Invalid save installation paths."), nullptr);
    return;
  }
  fl_method_call_respond_success(
      method_call,
      install_saved_file(fl_value_get_string(staged), fl_value_get_string(destination)),
      nullptr);
}

}  // namespace

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "mushagaeshi_binary_editor");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "mushagaeshi_binary_editor");
  }

  gtk_window_set_default_size(window, 1280, 720);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));
  self->save_channel = fl_method_channel_new(
      fl_plugin_registry_get_messenger(FL_PLUGIN_REGISTRY(view)),
      "mushagaeshi/files",
      FL_METHOD_CODEC(fl_standard_method_codec_new()));
  fl_method_channel_set_method_call_handler(self->save_channel,
                                             save_method_call_handler, self,
                                             nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_object(&self->save_channel);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
