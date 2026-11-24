const fs=require("fs");
const ops=JSON.parse(fs.readFileSync("tools/character_motion_edits.json","utf8"));
const files=new Map();
for(const o of ops) {
let s=files.get(o.file)??fs.readFileSync(o.file,"utf8").replace(/\r\n/g,"\n");
if(o.old!==undefined){if(!s.includes(o.old))throw Error("Missing "+o.file+": "+o.old);s=s.replace(o.old,o.value);}
else {const a=s.indexOf(o.start);const b=o.end===null?s.length:s.indexOf(o.end,a+o.start.length);if(a<0||b<0)throw Error("Missing block "+o.start);s=s.slice(0,a)+o.value+s.slice(b);}
files.set(o.file,s);
}
for(const [file,s] of files)fs.writeFileSync(file,s);
console.log("Patched "+files.size+" animation files");

