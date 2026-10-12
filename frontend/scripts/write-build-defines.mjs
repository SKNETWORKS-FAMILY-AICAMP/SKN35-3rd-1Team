import {writeFileSync} from 'node:fs';

// Only these public browser settings are compiled. Never include VERCEL_TOKEN,
// GOOGLE_APPLICATION_CREDENTIALS, service accounts, or server secrets.
export function buildDefines(env) {
  const result = {ARTLOG_DEMO: env.ARTLOG_DEMO ?? 'true', AUTH_PROVIDER: env.AUTH_PROVIDER ?? 'firebase'};
  for (const key of ['API_BASE_URL','FIREBASE_API_KEY','FIREBASE_APP_ID','FIREBASE_MESSAGING_SENDER_ID','FIREBASE_PROJECT_ID','FIREBASE_AUTH_DOMAIN']) {
    result[key] = env[key] ?? '';
  }
  if (!['true','false'].includes(result.ARTLOG_DEMO)) throw new Error('ARTLOG_DEMO must be true or false.');
  if (!['auto','firebase','api'].includes(result.AUTH_PROVIDER)) throw new Error('AUTH_PROVIDER must be auto, firebase or api.');
  if (result.AUTH_PROVIDER === 'firebase') {
    const missing = Object.entries(result).filter(([key,value]) => key.startsWith('FIREBASE_') && !value).map(([key]) => key);
    if (missing.length) throw new Error(`Firebase web configuration missing: ${missing.join(', ')}`);
  }
  if (result.ARTLOG_DEMO === 'false' && (!result.API_BASE_URL || !result.API_BASE_URL.startsWith('https://'))) {
    throw new Error('Production API mode requires an explicit HTTPS API_BASE_URL.');
  }
  return result;
}

if (process.argv[1]?.endsWith('write-build-defines.mjs')) {
  const defines = buildDefines(process.env);
  writeFileSync('.dart-defines.vercel.json', JSON.stringify(defines));
  console.log(`Building Artlog: catalog=${defines.ARTLOG_DEMO === 'true' ? 'preview' : 'API'}, auth=${defines.AUTH_PROVIDER}`);
}
