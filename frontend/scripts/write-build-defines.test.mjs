import {test} from 'node:test';
import assert from 'node:assert/strict';
import {buildDefines} from './write-build-defines.mjs';

const publicConfig = {FIREBASE_API_KEY:'public-key',FIREBASE_APP_ID:'web-id',FIREBASE_MESSAGING_SENDER_ID:'sender',FIREBASE_PROJECT_ID:'artlog',FIREBASE_AUTH_DOMAIN:'artlog.firebaseapp.com'};
test('only allowlisted public settings are bundled',()=>{
  const result=buildDefines({...publicConfig,VERCEL_TOKEN:'private',GOOGLE_APPLICATION_CREDENTIALS:'private'});
  assert.equal(result.AUTH_PROVIDER,'firebase'); assert.equal(result.ARTLOG_DEMO,'true');
  assert.equal(result.VERCEL_TOKEN,undefined); assert.equal(result.GOOGLE_APPLICATION_CREDENTIALS,undefined);
});
test('missing Firebase values fail the build instead of deploying broken login',()=>{
  assert.throws(()=>buildDefines({}),/Firebase web configuration missing/);
});
test('API mode requires HTTPS backend URL',()=>{
  assert.throws(()=>buildDefines({...publicConfig,ARTLOG_DEMO:'false',API_BASE_URL:'http://localhost:8000'}),/HTTPS/);
  assert.equal(buildDefines({...publicConfig,ARTLOG_DEMO:'false',API_BASE_URL:'https://api.example.org'}).ARTLOG_DEMO,'false');
});
