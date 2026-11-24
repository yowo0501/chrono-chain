import json,re,zipfile,xml.etree.ElementTree as ET
from pathlib import Path
root=Path(__file__).resolve().parents[1]
source=Path('E:/크로노 체인/프롤로그 챕터 스크립트.docx')
with zipfile.ZipFile(source) as z:
    tree=ET.fromstring(z.read('word/document.xml'))
ns={'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
lines=[''.join(p.itertext()) for p in []]
lines=[''.join(t.text or '' for t in p.findall('.//w:t',ns)) for p in tree.findall('.//w:body//w:p',ns)]
def line(i):
    s=lines[i]
    if ':' in s:
        who,text=s.split(':',1)
    else: who,text='괄호',s
    if '괄호' in who: who='괄호'
    text=re.sub(r'\([^)]*\)','',text).strip()
    if i==166: text='지금은 집중 스택이 하나도 없어요. 집중해 볼까요?'
    d={'speaker':who,'text':text,'source_paragraph':i}
    if i in [106,109]: d['expression']='embarrassed' if i==106 else 'angry'
    return d
def group(ids):return [line(i) for i in ids]
groups={
'opening':group([4,6,10,12,14,16,18,22,24,28,32]),
'confrontation':group([37,41,43,45,47,49,53,55,57,59,63]),
'attack_intro':group([80,81]),'attack_qte':group([83,84]),'attack_hit':group([88,89]),'attack_miss':group([91,92,93,94,95]),
'guard_intro':group([96]),'guard_qte':group([98]),'guard_miss_both':group([105,106,108,109]),'guard_miss_only':group([105,106,111,112,113]),'free_battle':group([115,116]),
'chase':group([122,123,124,125,127]),'dash':group([130,131,132,133,134,135]),'sighting':group([138]),'lockon':group([141]),'multi_qte':group([144]),'next_pack':group([148]),
'final_intro':group([153,154,155,156,157]),'flick_after':group([159,160,161]),'focus_intro':group([163,164,165,166]),'focus_after':group([168]),'special_intro':group([171]),'timer_intro':group([173]),
'victory':group([177,178,179]),'novel':group(list(range(183,191))),'ending':group(list(range(192,203))),'logo':group([204,205,206])}
groups['victory']=[x for x in groups['victory'] if x['source_paragraph'] not in [178,179]]
for entry in groups['ending']:
    if entry['source_paragraph']==194: entry['text']='과거를 잃어버린 소년과,'
    if entry['source_paragraph']==195: entry['text']='미래를 잃어버린 소녀의…라고 하면 될 것 같아요.'
groups['logo'][-1]['text']='아주, 아주 평범한 거리에서 시작됩니다…'
(root/'data/prologue_chapter.json').write_text(json.dumps({'source':source.name,'groups':groups},ensure_ascii=False,indent=2),encoding='utf-8')
(root/'docs/prologue-chapter-source.txt').write_text('\n'.join(lines),encoding='utf-8')
print('Source paragraphs:',len(lines),'dialogue lines:',sum(len(x) for x in groups.values()))
