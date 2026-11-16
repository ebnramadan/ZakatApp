const {GoogleAuth} = require('google-auth-library');
const {initializeApp, applicationDefault} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const {getAuth} = require('firebase-admin/auth');
const fs = require('node:fs');
(async () => {
  const project = 'zakat-app-36c58';
  initializeApp({credential: applicationDefault(), projectId: project});
  const client = await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
  let incomplete = false;
  try {
    const permissions=['firebaserules.rulesets.create','firebaserules.releases.create','firebaserules.releases.update','datastore.entities.get','datastore.entities.list','datastore.entities.create','datastore.entities.update','firebaseauth.users.get','firebaseauth.users.list'];
    const result=await client.request({url:`https://cloudresourcemanager.googleapis.com/v1/projects/${project}:testIamPermissions`,method:'POST',data:{permissions}});
    const present=new Set(result.data.permissions||[]);
    const missing=permissions.filter(p=>!present.has(p));
    console.log('Missing deployment/reminder permissions:',missing.length?missing.join(', '):'none');
    if(missing.length)incomplete=true;
  } catch(e) {console.log('Permission check failed:',e.response?.status||e.code);incomplete=true;}
  try {await getFirestore().collection('users').limit(1).get();console.log('Firestore access: confirmed (no account data logged).');}
  catch(e){console.log('Firestore access unavailable:',e.code);incomplete=true;}
  try {await getAuth().listUsers(1);console.log('Firebase Auth read access: confirmed (no account data logged).');}
  catch(e){console.log('Firebase Auth read access unavailable:',e.code);incomplete=true;}
  try {
    const sites=await client.request({url:`https://firebasehosting.googleapis.com/v1beta1/projects/${project}/sites`,params:{pageSize:100}});
    const owned=new Set((sites.data.sites||[]).map(s=>s.name.split('/').pop()));
    let chosen;
    for(const candidate of ['zakat-tracker','zakat-tracker-app','zakat-tracker-36c58']) {
      if(owned.has(candidate)){chosen=candidate;break;}
      try {
        await client.request({url:`https://firebasehosting.googleapis.com/v1beta1/projects/${project}/sites`,method:'POST',params:{siteId:candidate},data:{appId:'1:6510733442:web:b87850da40e5cbdbebac9b'}});
        chosen=candidate;break;
      }catch(e){if([400,409].includes(e.response?.status)){console.log('Friendly name unavailable:',candidate);continue;}throw e;}
    }
    if(!chosen)throw new Error('No friendly name could be claimed');
    console.log('Selected free Hosting URL:',`https://${chosen}.web.app`);
    if(process.env.GITHUB_STEP_SUMMARY)fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY,`\nFriendly site reserved: https://${chosen}.web.app\n`);
    const config=await client.request({url:`https://identitytoolkit.googleapis.com/admin/v2/projects/${project}/config`,headers:{'x-goog-user-project':project}});
    const domains=config.data.authorizedDomains||[];
    console.log('Friendly domain authorized for Google login:',domains.includes(`${chosen}.web.app`));
    if(!domains.includes(`${chosen}.web.app`))console.log(`ACTION NEEDED: Firebase Authentication → Settings → Authorized domains: add ${chosen}.web.app and ${chosen}.firebaseapp.com. Existing app stays on its current URL until configured.`);
  }catch(e){console.log('Friendly URL setup incomplete:',e.response?.status||e.code||e.message);incomplete=true;}
  console.log('Email sender secret present:',Boolean(process.env.RESEND_API_KEY));
  console.log('Verified sender address secret present:',Boolean(process.env.REMINDER_FROM));
  if(!process.env.RESEND_API_KEY||!process.env.REMINDER_FROM)incomplete=true;
  if(incomplete)process.exitCode=1;
})().catch(e=>{console.error('Preflight failed:',e.code||e.message);process.exitCode=1;});
