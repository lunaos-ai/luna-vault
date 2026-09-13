#include "CLibSecret.h"

#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
    const char *name;
    unsigned int type;
} VVSchemaAttr;

typedef struct {
    const char *name;
    unsigned int flags;
    VVSchemaAttr attributes[32];
    int reserved;
    void *reserved1;
    void *reserved2;
    void *reserved3;
    void *reserved4;
    void *reserved5;
    void *reserved6;
    void *reserved7;
} VVSchema;

typedef struct {
    unsigned int domain;
    int code;
    char *message;
} VVGError;

typedef int (*VVStoreFn)(
    const VVSchema *, const char *, const char *, const char *,
    void *, void **, ...
);
typedef char *(*VVLookupFn)(const VVSchema *, void *, void **, ...);
typedef int (*VVClearFn)(const VVSchema *, void *, void **, ...);
typedef void (*VVFreeFn)(void *);

static void *libsecret_handle;
static void *glib_handle;
static VVStoreFn store_fn;
static VVLookupFn lookup_fn;
static VVClearFn clear_fn;
static VVFreeFn password_free_fn;
static VVFreeFn error_free_fn;
static int resolved;
static int available;

static char *dup_str(const char *s);

static char *dup_error_message(void *error) {
    VVGError *gerror = (VVGError *)error;
    if (gerror == NULL || gerror->message == NULL) {
        return dup_str("libsecret error");
    }
    return dup_str(gerror->message);
}

static char *dup_str(const char *s) {
    size_t n;
    char *out;
    if (s == NULL) {
        return NULL;
    }
    n = strlen(s);
    out = (char *)malloc(n + 1);
    if (out == NULL) {
        return NULL;
    }
    memcpy(out, s, n + 1);
    return out;
}

static const VVSchema *schema(void) {
    static VVSchema s;
    static int inited;
    if (!inited) {
        memset(&s, 0, sizeof(s));
        s.name = "dev.vibevault.MasterKey";
        s.attributes[0].name = "account";
        inited = 1;
    }
    return &s;
}

static void free_error(void *error) {
    if (error != NULL && error_free_fn != NULL) {
        error_free_fn(error);
    }
}

static void resolve(void) {
    if (resolved) {
        return;
    }
    resolved = 1;
    libsecret_handle = dlopen("libsecret-1.so.0", RTLD_LAZY | RTLD_LOCAL);
    if (libsecret_handle == NULL) {
        return;
    }
    glib_handle = dlopen("libglib-2.0.so.0", RTLD_LAZY | RTLD_LOCAL);
    store_fn = (VVStoreFn)dlsym(libsecret_handle, "secret_password_store_sync");
    lookup_fn = (VVLookupFn)dlsym(libsecret_handle, "secret_password_lookup_sync");
    clear_fn = (VVClearFn)dlsym(libsecret_handle, "secret_password_clear_sync");
    password_free_fn = (VVFreeFn)dlsym(libsecret_handle, "secret_password_free");
    if (password_free_fn == NULL && glib_handle != NULL) {
        password_free_fn = (VVFreeFn)dlsym(glib_handle, "g_free");
    }
    if (glib_handle != NULL) {
        error_free_fn = (VVFreeFn)dlsym(glib_handle, "g_error_free");
    }
    if (store_fn != NULL && lookup_fn != NULL && clear_fn != NULL) {
        available = 1;
    }
}

int vv_secret_is_available(void) {
    resolve();
    return available;
}

int vv_secret_lookup(const char *account, char **out_hex, char **out_error) {
    void *error = NULL;
    char *password;
    if (out_hex != NULL) {
        *out_hex = NULL;
    }
    if (out_error != NULL) {
        *out_error = NULL;
    }
    resolve();
    if (!available || account == NULL) {
        return 1;
    }
    password = lookup_fn(schema(), NULL, &error, "account", account, NULL);
    if (error != NULL) {
        if (out_error != NULL) {
            *out_error = dup_error_message(error);
        }
        free_error(error);
        if (password != NULL && password_free_fn != NULL) {
            password_free_fn(password);
        }
        return 3;
    }
    if (password == NULL) {
        return 2;
    }
    if (out_hex != NULL) {
        *out_hex = dup_str(password);
    }
    if (password_free_fn != NULL) {
        password_free_fn(password);
    }
    return 0;
}

int vv_secret_store(
    const char *account,
    const char *label,
    const char *hex,
    char **out_error
) {
    void *error = NULL;
    int ok;
    if (out_error != NULL) {
        *out_error = NULL;
    }
    resolve();
    if (!available || account == NULL || hex == NULL) {
        return 1;
    }
    ok = store_fn(
        schema(),
        NULL,
        label != NULL ? label : "Vibe Vault master key",
        hex,
        NULL,
        &error,
        "account",
        account,
        NULL
    );
    if (!ok || error != NULL) {
        if (out_error != NULL) {
            *out_error = error != NULL
                ? dup_error_message(error)
                : dup_str("secret_password_store_sync failed");
        }
        free_error(error);
        return 3;
    }
    return 0;
}

int vv_secret_clear(const char *account, char **out_error) {
    void *error = NULL;
    if (out_error != NULL) {
        *out_error = NULL;
    }
    resolve();
    if (!available || account == NULL) {
        return 1;
    }
    (void)clear_fn(schema(), NULL, &error, "account", account, NULL);
    if (error != NULL) {
        if (out_error != NULL) {
            *out_error = dup_error_message(error);
        }
        free_error(error);
        return 3;
    }
    return 0;
}

void vv_secret_string_free(char *s) {
    free(s);
}
