const {GoogleAuth}=require('google-auth-library');
(async()=>{
 const auth=new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']});
 const client=await auth.getClient();
 console.log('Deployment service account:',(await auth.getCredentials()).client_email||'unavailable');
 const permissions=['cloudfunctions.functions.create','cloudfunctions.functions.update','iam.serviceAccounts.actAs','secretmanager.secrets.create','serviceusage.services.enable','cloudscheduler.jobs.create','cloudscheduler.jobs.update'];
 const result=await client.request({url:'https://cloudresourcemanager.googleapis.com/v1/projects/zakat-app-36c58:testIamPermissions',method:'POST',data:{permissions}});
 const missing=permissions.filter(p=>!(result.data.permissions||[]).includes(p));
 if(missing.length){console.error('Server delivery deployment is blocked. Missing permissions: '+missing.join(', '));process.exitCode=1;}
 else console.log('Server delivery deployment permissions confirmed. Firebase will also require a billing-enabled project; this workflow does not enable billing.');
})().catch(()=>{console.error('Could not verify server delivery deployment access.');process.exitCode=1;});
