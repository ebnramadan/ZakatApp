const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),out=path.join(root,'functions/lib');
for(const name of ['scripts/monthly-progress-sheet.cjs','scripts/monthly-reminders.cjs','assets/translations/ar.json']){
  const target=path.join(out,name);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(path.join(root,name),target);
}
