const {GoogleAuth} = require('google-auth-library');
(async()=>{
 const client=await new GoogleAuth({scopes:['https://www.googleapis.com/auth/cloud-platform']}).getClient();
 const response=await client.request({url:'https://identitytoolkit.googleapis.com/admin/v2/projects/zakat-app-36c58/config',headers:{'x-goog-user-project':'zakat-app-36c58'},params:{fields:'authorizedDomains'}});
 if(!(response.data.authorizedDomains||[]).includes('ztracker.web.app'))throw new Error('Add ztracker.web.app in Firebase Authentication → Settings → Authorized domains before deploying the new URL.');
 console.log('Friendly URL is authorized for Google sign-in.');
})().catch(e=>{console.error(e.message);process.exitCode=1;});
