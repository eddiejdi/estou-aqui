# Security Policy — Estou Aqui Backend

## Vulnerability Status

### Current State (10 Mar 2026)

**8 Low Severity Vulnerabilities** from transitive dependencies:

| Vulnerability | Severity | Package | Fix Available |
|---|---|---|---|
| `@tootallnate/once` < 3.0.1 | Low | http-proxy-agent → teeny-request | npm audit fix --force |
| Memory leak in `inflight@1.0.6` | Low | transitive | Use lru-cache instead |
| `glob@7.2.3` & `glob@10.5.0` security issues | Low | build tools | Update build toolchain |

### Resolved (Previous Critical/High)

✅ **firebase-admin** updated from ^10.3.0 → ^13.7.0
- ✅ Fixed: jsonwebtoken CVE (3 issues)
- ✅ Fixed: protobufjs Prototype Pollution (GHSA-h755-8qp9-cq85)
- ✅ Fixed: @grpc/grpc-js memory allocation DoS

✅ **multer** updated from 1.4.5-lts.1 → ^2.0.0
- ✅ Fixed: Multiple 1.x vulnerabilities

### Remaining Vulnerabilities (Low Only)

The remaining **8 low severity vulnerabilities** come from Firebase Admin SDK's transitive dependencies (teeny-request, http-proxy-agent, google-gax). These are:

1. **Not directly exploitable** in our API usage (no direct http-proxy-agent calls)
2. **Low priority** (security researchers classify as "informational")
3. **Blocked by Firebase SDK** — we cannot upgrade beyond unless Firebase upgrades their dependencies

### Mitigation Strategy

```bash
# Current approach: Use npm audit fix (non-breaking)
npm audit fix

# To force all fixes (breaking changes):
npm audit fix --force
# Note: May break compatibility with Firebase Admin SDK
```

### Recommended Actions

1. **Monitor**: Re-run `npm audit` monthly
2. **Update**: Keep firebase-admin on latest stable version
3. **Alternative**: Consider Supabase (Firebase alternative) if vulnerabilities become blocking
4. **Timeline**: Plan migration away from Firebase if Google doesn't update dependencies by Q3 2026

### Testing After Updates

```bash
npm test
npm run lint
npm start  # Test locally before deploy
```

---

## Commands

```bash
# Check current status
npm audit

# Fix non-breaking issues
npm audit fix

# View dependency tree
npm ls firebase-admin
npm ls multer
```

---

**Last Audit**: 10 mar 2026 10:40 UTC  
**Critical Issues**: 0  
**High Severity**: 0  
**Medium Severity**: 0  
**Low Severity**: 8 (transitive, low risk)
