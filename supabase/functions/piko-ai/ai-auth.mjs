const uuid = /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;

// getUser verifies the token before any decoded claim is used. A valid JWT can
// outlive sign-out, so sensitive AI operations also require its live session.
export function createAnonymousAuthenticator(client) {
  return async function authenticate(jwt) {
    try {
      if (!client || typeof jwt !== 'string') return null;
      const {data, error} = await client.auth.getUser(jwt);
      const user = data?.user;
      if (error || user?.is_anonymous !== true || !uuid.test(user?.id ?? '')) return null;
      const parts = jwt.split('.');
      if (parts.length !== 3 || !/^[A-Za-z0-9_-]+$/.test(parts[1])) return null;
      const raw = atob(parts[1].replace(/-/g, '+').replace(/_/g, '/'));
      const claims = JSON.parse(new TextDecoder('utf-8', {fatal: true}).decode(
        Uint8Array.from(raw, character => character.charCodeAt(0))));
      if (claims?.sub !== user.id || !uuid.test(claims?.session_id ?? '') ||
          !Number.isFinite(claims?.exp) || claims.exp <= Date.now() / 1000) return null;
      const session = await client.rpc('piko_ai_session_active', {
        p_user_id: user.id, p_session_id: claims.session_id,
      });
      return !session.error && session.data === true ? user.id : null;
    } catch {
      // Never expose token, claims, credentials or backend exception details.
      return null;
    }
  };
}
