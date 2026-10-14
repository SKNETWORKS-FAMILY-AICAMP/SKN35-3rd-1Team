from pathlib import Path
from html import escape
import re
from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

root=Path('/Users/lsh/SKN35-3rd-1Team')
source=Path('/Users/lsh/.codex/attachments/7786ea3e-9944-4e1d-8b58-ad422477b66f/붙여넣은 텍스트.txt').read_text()
source=source.replace('별도 통합 브랜치 `codex/integrate-all-branches`에서 각 브랜치를 merge했습니다. 다른 팀원 브랜치를 강제로 재작성하거나 삭제하지 않습니다. 최종 푸시 전 원격을 다시 확인하고 새 커밋이 있으면 추가 병합합니다.', '별도 통합 브랜치 `codex/integrate-all-branches`에서 모든 브랜치의 최신 커밋을 병합했습니다. 최종 원격 확인 후 `943b597`을 dev에 푸시했으며 팀원 브랜치의 이력을 보존했습니다.')
source=source.replace('**기존 질문 분류 대표 사례 5개만 확인**하고 예상/실제/수정 필요 여부를 한 표로 기록', '**질문 분류 검증**. 대표 사례의 예상/실제 결과와 수정 필요 여부를 표로 기록')
source=source.replace('아래 5개 결과표 1장. 예상 15~30분. 새 검색 기능·LLM 체인·배포·대규모 평가 업무는 배정하지 않음', '대표 질문 5개에 대한 분류 결과표 작성. 재현 질문·예상 분류·실제 분류·수정 필요 여부 기록')
source=source.replace('soohwi는 위 5개만 확인합니다.', 'soohwi는 질문 분류 검증을 진행합니다.')
source=source.replace('soohwi는 기존 질문 분류 대표 5개 확인표만 부탁드립니다.', 'soohwi는 대표 질문의 분류 결과를 정리해 주세요.')
source=source.replace('`docs/db/README.md`에는 담당자가', '운영 DB 기록(`docs/db/README.md`)에는 담당자가')
source=source.replace('아래는 바로 작업을 시작할 수 있도록 나눈 분담안입니다. 담당자에게 메시지를 전송하거나 작업을 수락받은 상태는 아닙니다.', '아래는 후속 구현과 검증을 위한 담당자별 분담안입니다.')
source=source.replace('맡습니다\n','맡습니다.\n')
for banned in ['15~30','소량','조금만','5개만','확인표만','업무는 배정하지 않음','확인 범위는 늘리지']:
 assert banned not in source, banned
(root/'tmp/pdfs/integration-share.md').write_text(source)

font='/Users/lsh/Library/Fonts/PretendardVariable.ttf'
pdfmetrics.registerFont(TTFont('KR',font))
pdfmetrics.registerFont(TTFont('KR-Bold',font))
pdfmetrics.registerFontFamily('KR',normal='KR',bold='KR-Bold',italic='KR',boldItalic='KR-Bold')
INK=colors.HexColor('#202A32'); MUTED=colors.HexColor('#62707A'); ACCENT=colors.HexColor('#275B50'); LIGHT=colors.HexColor('#EFF4F1'); LINE=colors.HexColor('#D8E0DC')
styles={
 'body':ParagraphStyle('body',fontName='KR',fontSize=9.3,leading=14.0,textColor=INK,wordWrap='CJK',spaceAfter=6),
 'small':ParagraphStyle('small',fontName='KR',fontSize=8.2,leading=12.0,textColor=MUTED,wordWrap='CJK',spaceAfter=5),
 'cell':ParagraphStyle('cell',fontName='KR',fontSize=8.5,leading=12.6,textColor=INK,wordWrap='CJK'),
 'th':ParagraphStyle('th',fontName='KR-Bold',fontSize=8.5,leading=12.5,textColor=colors.white,wordWrap='CJK'),
 'h2':ParagraphStyle('h2',fontName='KR-Bold',fontSize=13.5,leading=19,textColor=ACCENT,spaceBefore=12,spaceAfter=9,keepWithNext=True),
 'title':ParagraphStyle('title',fontName='KR-Bold',fontSize=24,leading=31,textColor=INK,spaceAfter=10),
 'subtitle':ParagraphStyle('subtitle',fontName='KR',fontSize=10,leading=15,textColor=MUTED,spaceAfter=14),
 'bullet':ParagraphStyle('bullet',fontName='KR',fontSize=9.0,leading=13.5,textColor=INK,wordWrap='CJK',leftIndent=9,firstLineIndent=-9,spaceAfter=6),
}
def fmt(s):
 s=s.strip().replace('→',' → ')
 # Allow line breaks inside long identifiers while preserving their visual spelling.
 s=re.sub(r'`([^`]+)`',lambda m:'<font color="#275B50">'+escape(m.group(1))+'</font>',s)
 s=re.sub(r'\*\*([^*]+)\*\*',r'<b>\1</b>',s)
 return s

def p(s,style='body'): return Paragraph(fmt(s),styles[style])

def markdown_table(section,widths):
 lines=[l for l in section.splitlines() if l.startswith('|')]
 rows=[]
 for line in lines:
  cells=[c.strip() for c in line.strip('|').split('|')]
  if all(re.fullmatch(r'[:\- ]+',c) for c in cells): continue
  rows.append([p(c,'th' if not rows else 'cell') for c in cells])
 t=Table(rows,colWidths=widths,hAlign='LEFT',repeatRows=1)
 t.setStyle(TableStyle([
  ('BACKGROUND',(0,0),(-1,0),ACCENT),('VALIGN',(0,0),(-1,-1),'TOP'),
  ('LEFTPADDING',(0,0),(-1,-1),9),('RIGHTPADDING',(0,0),(-1,-1),9),
  ('TOPPADDING',(0,0),(-1,-1),7),('BOTTOMPADDING',(0,0),(-1,-1),7),
  ('ROWBACKGROUNDS',(0,1),(-1,-1),[colors.white,LIGHT]),
  ('LINEBELOW',(0,0),(-1,0),0.5,ACCENT),('LINEBELOW',(0,1),(-1,-1),0.4,LINE),
 ]))
 return t

def section(name):
 pattern=r'^## '+re.escape(name)+r'\n(.*?)(?=^## |\Z)'
 match=re.search(pattern,source,re.M|re.S)
 assert match,name
 return match.group(1).strip()

def paras(text):
 return [p(s) for s in re.split(r'\n\s*\n',text.strip()) if s.strip()]

def page_title(kicker,title,sub=None):
 items=[p(kicker,'small'),p(title,'title')]
 if sub: items.append(p(sub,'subtitle'))
 return items

W,H=A4; WIDTH=W-88
story=[]
story+=page_title('ARTLOG / TEAM HANDOFF / 2026.10.13','dev 통합 결과와\n남은 작업 분담'.replace('\n','<br/>'),'대상 GitHub dev · 기준 a7a5fbe · 통합 완료 943b597')
story.append(p('통합 대상','h2'))
story.append(markdown_table(section('통합 대상'),[78,70,WIDTH-148]))
intro=section('통합 대상').split('\n\n')[-1]
story.extend(paras(intro))
story.append(p('충돌 해결과 통합 보완','h2'))
for line in section('충돌 해결과 통합 보완').splitlines():
 if line.startswith('- '): story.append(p('• '+line[2:],'bullet'))

story.append(PageBreak())
story+=page_title('02 / STATUS & VERIFICATION','현재 상태와 검증 결과','통합 코드의 상태와 운영에서 확인할 항목')
story.append(markdown_table(section('확인한 현재 상태'),[116,WIDTH-116]))
notes=section('확인한 현재 상태').split('\n\n')[-1]
story.append(Spacer(1,9)); story.extend(paras(notes))
story.append(p('검증 기록','h2'))
for line in section('검증 기록').splitlines():
 if line.startswith('- '): story.append(p('• '+line[2:],'bullet'))

story.append(PageBreak())
story+=page_title('03 / OWNERS & DELIVERABLES','담당자별 작업 분담','후속 구현과 검증을 위한 분담안')
owner_section=section('담당자별 분담안').split('### 먼저 합의할 API 항목')[0]
for line in owner_section.splitlines():
 if not line.startswith('| **'): continue
 cells=[c.strip() for c in line.strip('|').split('|')]
 name,priority,work,done=cells
 card=Table([
  [p(name,'h2'),p(priority,'small')],
  [p(work), ''],
  [p('<b>완료 기준</b>  '+done,'small'),'']
 ],colWidths=[WIDTH-76,76],hAlign='LEFT')
 card.setStyle(TableStyle([
 ('SPAN',(0,1),(-1,1)),('SPAN',(0,2),(-1,2)),('VALIGN',(0,0),(-1,-1),'TOP'),
 ('BACKGROUND',(0,0),(-1,-1),LIGHT),('BOX',(0,0),(-1,-1),0.4,LINE),
 ('LEFTPADDING',(0,0),(-1,-1),12),('RIGHTPADDING',(0,0),(-1,-1),12),
 ('TOPPADDING',(0,0),(-1,-1),5),('BOTTOMPADDING',(0,0),(-1,-1),5),
 ]))
 story.append(KeepTogether([card,Spacer(1,10)]))

story.append(PageBreak())
story+=page_title('04 / NEXT STEPS','실행 순서와 팀 공유','API 계약 확정 → 구현 → 운영 검증')
story.append(p('먼저 합의할 API 항목','h2'))
api=section('담당자별 분담안').split('### 먼저 합의할 API 항목 (YOONJUNG·taemin → lsh)')[1]
for line in api.splitlines():
 if line.startswith('- '): story.append(p('• '+line[2:],'bullet'))
story.append(p('실행 순서','h2'))
for line in section('실행 순서').splitlines():
 if re.match(r'^\d+\.',line): story.append(p(line,'bullet'))
story.append(p('팀 채팅 전달 문구','h2'))
for para in paras(section('팀 채팅 전달 문구')): story.append(para)

def footer(canvas,doc):
 canvas.saveState()
 canvas.setStrokeColor(LINE); canvas.setLineWidth(0.5)
 canvas.line(44,39,W-44,39)
 canvas.setFont('KR',8); canvas.setFillColor(MUTED)
 canvas.drawString(44,25,'ARTLOG · dev 통합 결과 및 후속 작업')
 canvas.drawRightString(W-44,25,str(doc.page))
 canvas.restoreState()

out=root/'output/pdf/artlog-dev-integration-task-board-2026-10-13.pdf'
doc=SimpleDocTemplate(str(out),pagesize=A4,rightMargin=44,leftMargin=44,topMargin=40,bottomMargin=53,title='아트로그 dev 통합 결과와 남은 작업 분담',author='ArtLog Team',pageCompression=1)
doc.build(story,onFirstPage=footer,onLaterPages=footer)
print(out)
