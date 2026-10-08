// Usage: node tool/build_legal_site.cjs [--check] [--release]
// No third-party renderer, remote assets, scripts or network requests.
const fs=require('fs'),path=require('path'),crypto=require('crypto'),assert=require('assert/strict');
const root=path.resolve(__dirname,'..'),input=path.join(root,'assets/legal'),out=path.join(root,'build_artifacts/legal_site');
const siteDocuments=['privacy_policy_zh.md','user_agreement_zh.md'];
const check=process.argv.includes('--check'),release=process.argv.includes('--release');
const escape=s=>s.replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','"').replaceAll("'",'&#39;');
const decode=s=>s.replace(/&#39;/g,"'").replace(/"/g,'"').replace(/&gt;/g,'>').replace(/&lt;/g,'<').replace(/&amp;/g,'&');
const hash=s=>crypto.createHash('sha256').update(s).digest('hex');
const inline=s=>escape(s).replace(/`([^`]+)`/g,'<code>$1</code>');
const normalize=s=>s.replace(/\s+/gu,'');
const css=':root{color-scheme:light dark}body{font-family:system-ui,sans-serif;line-height:1.8;margin:0;padding:24px;color:#242124;background:#fff}main{max-width:960px;margin:auto}h1{font-size:28px}h2{font-size:21px;margin-top:32px}p{overflow-wrap:anywhere}table{width:100%;border-collapse:collapse;font-size:15px}td,th{border:1px solid #bbb;padding:12px;vertical-align:top;overflow-wrap:anywhere}th{background:#f6edf1}a{color:#993653}nav{margin-bottom:24px}code{font-family:inherit}@media(max-width:600px){body{padding:16px}table,tbody,tr,td,th{display:block}thead{display:none}tr{margin-bottom:16px}td{border-bottom:0}td:last-child{border-bottom:1px solid #bbb}td:first-child{font-weight:600}}@media(prefers-color-scheme:dark){body{background:#161416;color:#eee}th{background:#31252b}a{color:#ffb3ca}}';
function render(md){let content=[],plain=[],table=false,first=false;for(const raw of md.split(/\r?\n/)){const line=raw.trim();if(line.startsWith('|')){const cells=line.split('|').slice(1,-1).map(x=>x.trim());if(cells.every(x=>/^:?-+:?$/.test(x)))continue;if(!table){content.push('<table>');table=true;first=true;}const tag=first?'th':'td';content.push('<tr>'+cells.map(x=>`<${tag}>${inline(x)}</${tag}>`).join('')+'</tr>');plain.push(...cells.map(x=>x.replaceAll('`','')));first=false;continue;}if(table){content.push('</table>');table=false;}if(!line)continue;const m=line.match(/^(#{1,6}) (.*)$/);const text=m?m[2]:line;const tag=m?'h'+m[1].length:'p';content.push(`<${tag}>${inline(text)}</${tag}>`);plain.push(text.replaceAll('`',''));}if(table)content.push('</table>');return {body:content.join('\n'),text:plain.join('\n')};}
fs.mkdirSync(out,{recursive:true});
const expectedHtml=new Set(siteDocuments.map(file=>file.replace('.md','.html')));
for(const file of fs.readdirSync(out).filter(file=>file.endsWith('.html')&&!expectedHtml.has(file))){
  if(check) assert.fail('Unexpected HTML artifact: '+file);
  fs.rmSync(path.join(out,file));
}
const manifest={policy_version:'xy-legal-v2',source:'assets/legal',public_url:null,release_ready:false,documents:[],blockers:[]};
for(const file of siteDocuments){
  const md=fs.readFileSync(path.join(input,file),'utf8'),r=render(md),title=md.split('\n')[0].replace(/^# /,'');
 const html='<!doctype html>\n<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta name="referrer" content="no-referrer"><meta http-equiv="Content-Security-Policy" content="default-src \'none\'; style-src \'unsafe-inline\'; base-uri \'none\'; form-action \'none\'"><title>'+escape(title)+'</title><style>'+css+'</style></head><body><main>'+r.body+'</main></body></html>\n';
 const name=file.replace('.md','.html');
 if(check)assert.equal(fs.readFileSync(path.join(out,name),'utf8'),html,'HTML stale: '+name);else fs.writeFileSync(path.join(out,name),html);
 const visible=decode(r.body.replace(/<[^>]*>/g,''));assert.equal(normalize(visible),normalize(r.text),'Body text differs: '+file);
 const placeholders=[...new Set(md.match(/请发布方[^\n|。]+/g)??[])];
 manifest.documents.push({source:file,html:name,source_sha256:hash(md),html_sha256:hash(html),body_text_equal:true,placeholders});
 if(placeholders.length)manifest.blockers.push(name+': 联系地址等剩余字段待填写');
}
manifest.blockers.push('公开 HTTPS URL 待部署及免登录可访问验证','ML Kit 锁定版本诊断数据、保存期限、境外处理需发布方核验','最终签名包及真机冷启动/拒绝/撤回/权限/网络动态验收待完成','华为部分规范及应用宝动态页面正文待人工核验');
const report=JSON.stringify(manifest,null,2)+'\n';
if(check)assert.equal(fs.readFileSync(path.join(out,'manifest.json'),'utf8'),report);else fs.writeFileSync(path.join(out,'manifest.json'),report);
console.log(JSON.stringify({files:manifest.documents.length,body_text_equal:true,public_url:null,release_ready:false,blockers:manifest.blockers.length}));
if(release&&manifest.blockers.length){console.error('发布检查未通过：请处理 manifest.json 中的阻断项。');process.exitCode=2;}