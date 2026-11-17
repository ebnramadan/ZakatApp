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
    const permissions=['firebaserules.rulesets.create','firebaserules.releases.create','firebaserules.releases.update','datastore.entities.get','datastore.entities.list','datastore.entities.create','datastore.entities.update','datastore.entities.delete','firebaseauth.users.get'];
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
    const sites=await client.request({url:`https://firebasehosting.googleapis.com/v1beta1/projects/6510733442/sites`,params:{pageSize:100}});
    const owned=new Set((sites.data.sites||[]).map(s=>s.name.split('/').pop()));
    let chosen;
    for(const candidate of ['ztracker']) {
      if(owned.has(candidate)){chosen=candidate;break;}
      try {
        await client.request({url:`https://firebasehosting.googleapis.com/v1beta1/projects/6510733442/sites`,method:'POST',params:{siteId:candidate},data:{}});
        chosen=candidate;break;
      }catch(e){if([400,409].includes(e.response?.status)){console.log('Friendly name request rejected:',candidate,e.response?.status, e.response?.data?.error?.message || 'name unavailable');continue;}throw e;}
    }
    if(!chosen)throw new Error('No friendly name could be claimed');
    console.log('Selected free Hosting URL:',`https://${chosen}.web.app`);
    if(process.env.GITHUB_STEP_SUMMARY)fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY,`\nFriendly site reserved: https://${chosen}.web.app\n`);
    const config=await client.request({url:`https://identitytoolkit.googleapis.com/admin/v2/projects/${project}/config`,headers:{'x-goog-user-project':project},params:{fields:'authorizedDomains,signIn/email/enabled'}});
    const domains=config.data.authorizedDomains||[];
    console.log('Email/password sign-in enabled:',config.data.signIn?.email?.enabled===true);
    if(config.data.signIn?.email?.enabled!==true)incomplete=true;
    const google=await client.request({url:`https://identitytoolkit.googleapis.com/admin/v2/projects/${project}/defaultSupportedIdpConfigs/google.com`,params:{fields:'enabled'},headers:{'x-goog-user-project':project}});
    console.log('Google sign-in enabled:',google.data.enabled===true);
    if(google.data.enabled!==true)incomplete=true;
    console.log('Friendly domain authorized for Google login:',domains.includes(`${chosen}.web.app`));
    if(!domains.includes(`${chosen}.web.app`)){incomplete=true;console.log(`ACTION NEEDED: Firebase Authentication → Settings → Authorized domains: add ${chosen}.web.app and ${chosen}.firebaseapp.com. Existing app stays on its current URL until configured.`);}
  }catch(e){console.log('Friendly URL setup incomplete:',e.response?.status||e.code||e.message);incomplete=true;}
  try {
    const billing=await client.request({url:`https://cloudbilling.googleapis.com/v1/projects/${project}/billingInfo`});
    console.log('Server backend billing enabled:',billing.data.billingEnabled===true);
  }catch(e){console.log('Server backend billing check unavailable:',e.response?.status||e.code);}
  try {
    const permissions=['cloudfunctions.functions.create','cloudfunctions.functions.update','iam.serviceAccounts.actAs','secretmanager.secrets.create','serviceusage.services.enable'];
    const result=await client.request({url:`https://cloudresourcemanager.googleapis.com/v1/projects/${project}:testIamPermissions`,method:'POST',data:{permissions}});
    console.log('Missing server-backend deployment permissions:',permissions.filter(p=>!(result.data.permissions||[]).includes(p)).join(', ')||'none');
  }catch(e){console.log('Server backend permission check unavailable:',e.response?.status||e.code);}
  console.log('Email sender secret present:',Boolean(process.env.RESEND_API_KEY));
  console.log('Verified sender address secret present:',Boolean(process.env.REMINDER_FROM));
  console.log('Gmail SMTP secrets present:',Boolean(process.env.REMINDER_SMTP_USER && process.env.REMINDER_SMTP_APP_PASSWORD));
  if(!(process.env.RESEND_API_KEY&&process.env.REMINDER_FROM)&&!(process.env.REMINDER_SMTP_USER&&process.env.REMINDER_SMTP_APP_PASSWORD))incomplete=true;
  if(incomplete)process.exitCode=1;
})().catch(e=>{console.error('Preflight failed:',e.code||e.message);process.exitCode=1;});
