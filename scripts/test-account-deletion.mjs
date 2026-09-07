// Local PostgreSQL validation only. See docs/RELEASE_READINESS.md for the command.
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
const { PGlite } = await import(process.env.PGLITE_MODULE || '@electric-sql/pglite');
const db = new PGlite();
await db.exec(`
  create role anon; create role authenticated; create role service_role bypassrls;
  create schema auth;
  create table auth.users(id uuid primary key);
  create table auth.identities(user_id uuid references auth.users(id) on delete cascade, provider text);
  create function auth.uid() returns uuid language sql stable as
    $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  create function auth.role() returns text language sql stable as
    $$ select current_setting('request.jwt.claim.role', true) $$;
  grant usage on schema auth to authenticated, anon;
`);
for (const file of ['0001_ai_recipe.sql','0002_analytics.sql','0003_account_deletion.sql']) {
  await db.exec(await readFile(new URL(`../supabase/migrations/${file}`, import.meta.url), 'utf8'));
}
const a='00000000-0000-0000-0000-000000000001';
const b='00000000-0000-0000-0000-000000000002';
const c='00000000-0000-0000-0000-000000000003';
for (const id of [a,b,c]) {
  await db.query('insert into auth.users values ($1)',[id]);
  await db.query("insert into auth.identities values ($1, 'email')",[id]);
  await db.query('insert into public.ai_usage values ($1, current_date, 1)',[id]);
  await db.query(`insert into public.analytics_events
    (user_id,install_id,session_id,seq,name,occurred_at)
    values ($1,$1,$1,1,'screen_view',now())`,[id]);
}
await db.exec('set role anon');
await assert.rejects(db.query('select public.delete_own_account()'),{code:'42501'});
await db.exec('reset role');
await db.query("select set_config('request.jwt.claim.sub',$1,false)",[a]);
await db.query("select set_config('request.jwt.claim.role','authenticated',false)");
await db.exec('set role authenticated');
await assert.rejects(db.query('select public.delete_own_account($1)',[b]),{code:'42883'});
await db.query('select public.delete_own_account()');
await db.query('select public.delete_own_account()'); // lost-response retry
await assert.rejects(db.query(`insert into public.analytics_events
  (install_id,session_id,seq,name,occurred_at) values ($1,$1,2,'screen_view',now())`,[a]));
await db.exec('reset role');
for (const table of ['auth.users','auth.identities','public.analytics_events','public.ai_usage']) {
  const rows=(await db.query(`select count(*)::int as n from ${table}`)).rows;
  assert.equal(rows[0].n,2,table+' must retain the other two users');
}
// Force a failure after analytics deletion and ensure the entire RPC rolls back.
await db.exec(`create function auth.fail_delete() returns trigger language plpgsql as $$
  begin raise exception 'injected failure'; end; $$;
  create trigger fail_delete before delete on auth.users for each row execute function auth.fail_delete();`);
await db.query("select set_config('request.jwt.claim.sub',$1,false)",[b]);
await db.exec('set role authenticated');
await assert.rejects(db.query('select public.delete_own_account()'));
await db.exec('reset role');
assert.equal((await db.query('select count(*)::int as n from public.analytics_events')).rows[0].n,2);
assert.equal((await db.query('select count(*)::int as n from public.ai_usage')).rows[0].n,2);
await db.exec('drop trigger fail_delete on auth.users');
await db.query("update auth.identities set provider='apple' where user_id=$1",[c]);
await db.query("select set_config('request.jwt.claim.sub',$1,false)",[c]);
await db.exec('set role authenticated');
await assert.rejects(db.query('select public.delete_own_account()'));
await db.exec('reset role');
assert.equal((await db.query('select count(*)::int as n from auth.users')).rows[0].n,2);
await db.close();
console.log('PASS: anonymous denial, caller isolation, own data deletion, retry, deleted-JWT rejection, transaction rollback, Apple revocation guard');
