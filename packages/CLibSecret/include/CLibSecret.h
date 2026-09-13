#ifndef VV_CLIBSECRET_H
#define VV_CLIBSECRET_H

#ifdef __cplusplus
extern "C" {
#endif

/* Optional libsecret via dlopen. 0 = unavailable, 1 = available. */
int vv_secret_is_available(void);

/*
 * Lookup hex-encoded master key for account.
 * Returns 0 ok, 1 unavailable, 2 not found, 3 error.
 * Caller must vv_secret_string_free any non-NULL out pointers.
 */
int vv_secret_lookup(const char *account, char **out_hex, char **out_error);

int vv_secret_store(
    const char *account,
    const char *label,
    const char *hex,
    char **out_error
);

int vv_secret_clear(const char *account, char **out_error);

void vv_secret_string_free(char *s);

#ifdef __cplusplus
}
#endif

#endif
