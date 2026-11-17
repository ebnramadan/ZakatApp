const {initializeApp,applicationDefault}=require('firebase-admin/app');
const {getFirestore}=require('firebase-admin/firestore');
initializeApp({credential:applicationDefault(),projectId:'zakat-app-36c58'});
getFirestore().doc('_system/reportDelivery').set({mode:process.argv.includes('--github')?'github':'firebase',updatedAt:Date.now()}).then(()=>console.log('Email delivery mode updated.')).catch(()=>{console.error('Could not update email delivery mode.');process.exitCode=1;});
