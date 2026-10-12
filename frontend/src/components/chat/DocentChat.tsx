import { ArrowUpRight, Check, ChevronRight, ExternalLink, FileText, Send, Sparkles } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';
import type { Artwork } from '../../types/catalog';

type Message = { role: 'user' | 'assistant'; text: string; source?: boolean; outOfScope?: boolean };
export default function DocentChat({ art }: { art: Artwork }) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState('');
  const [busy, setBusy] = useState(false);
  const [showSources, setShowSources] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const scroll = useRef<HTMLDivElement>(null);
  useEffect(() => { scroll.current?.scrollTo({ top: scroll.current.scrollHeight, behavior: 'smooth' }); }, [messages, busy]);
  useEffect(() => () => { if (timer.current) clearTimeout(timer.current); }, []);
  const ask = (question: string) => {
    if (!question.trim() || busy) return;
    setMessages(current => [...current, { role: 'user', text: question.trim() }]);
    setInput(''); setBusy(true);
    timer.current = setTimeout(() => {
      let answer: Message;
      if (/피카소|달리|다빈치|다빈치|마티스|주식|날씨|음식/.test(question)) {
        answer = { role: 'assistant', text: '아직 이 질문에 답할 수 있는 자료가 준비되지 않았어요. 근거 없는 이야기를 전하기보다, 지금 함께 보고 있는 작품으로 돌아가 볼까요? 작품 정보나 감상 포인트를 물어보세요.', outOfScope: true };
      } else if (/언제|연도|몇 년|그린 때/.test(question)) {
        answer = { role: 'assistant', text: `작품 정보에 따르면 《${art.titleKo}》의 제작 시기는 ${art.year}입니다. 작가는 ${art.artistKo}예요. 아래 출처에서 원본 작품 정보를 직접 살펴볼 수 있어요.`, source: true };
      } else if (/감상|어디부터|색|붓|느낌|포인트/.test(question)) {
        answer = { role: 'assistant', text: `${art.note}\n\n정답을 찾기보다, 가장 먼저 눈에 들어온 부분에 잠시 머물러 보세요. 어떤 색이나 형태가 마음에 남나요?\n\n이 내용은 작품을 바라보는 감상 제안이에요.`, source: true };
      } else if (/누가|작가|제목|정보|소개|무슨 그림/.test(question)) {
        answer = { role: 'assistant', text: `지금 보고 계신 작품은 ${art.artistKo}의 《${art.titleKo}》(${art.year})입니다. 영문 제목은 “${art.title}”예요. 작품의 세부 정보는 아래 원본 출처에서 확인할 수 있어요.`, source: true };
      } else {
        answer = { role: 'assistant', text: '이 목업에 준비된 작품 정보에서는 질문에 대한 근거를 찾지 못했어요. 현재는 작품명·작가·제작 시기와 감상 포인트에 관한 예시 대화를 체험할 수 있어요. 아래 질문으로 이야기를 이어가 볼까요?', outOfScope: true };
      }
      setMessages(current => [...current, answer]); setBusy(false);
    }, 650);
  };
  const source = art.museumUrl ?? art.sourceUrl;
  const sourceName = source.includes('metmuseum') ? '메트로폴리탄 미술관' : source.includes('artic.edu') ? '시카고 미술관' : source.includes('belvedere') ? '벨베데레 미술관' : 'Wikimedia Commons';
  return <section className="docent-panel" aria-label="작품 도슨트 대화">
    <div className="docent-header"><div className="docent-avatar"><Sparkles size={19}/></div><div><h2>당신의 도슨트</h2><p><span className="status-dot"/>함께 그림을 보고 있어요</p></div><span className="demo-badge">체험용</span></div>
    <div className="context-strip"><FileText size={14}/><span>{art.titleKo}</span><span className="context-tag">작품 맥락 유지</span></div>
    <div className="chat-messages" ref={scroll} aria-live="polite"><div className="assistant-intro"><div className="eyebrow"><Sparkles size={13}/> A CONVERSATION WITH ART</div><h3>조금 더 가까이,<br/>그림 속으로.</h3><p>안녕하세요. 《{art.titleKo}》을<br/>함께 감상할 도슨트예요.<br/>어떤 이야기가 궁금하신가요?</p><div className="source-confidence"><Check size={13}/> 준비된 작품 정보로 답해요</div></div>
      {messages.map((message, i) => <div key={i} className={`chat-message ${message.role}`}><span className="message-author">{message.role === 'user' ? '나의 질문' : <><Sparkles size={13}/> 아트로그 도슨트</>}</span><div className={`message-bubble ${message.outOfScope ? 'out-of-scope' : ''}`}>{message.outOfScope && <span className="scope-label">자료 범위 안내</span>}{message.text}{message.source && <button className="inline-citation" onClick={()=>setShowSources(true)} aria-label="답변 출처 1 보기">1</button>}</div>{message.source && <button className="source-chip" onClick={()=>setShowSources(true)}><FileText size={12}/>{sourceName} · 작품 정보<ArrowUpRight size={12}/></button>}</div>)}
      {busy && <div className="typing-indicator" role="status" aria-label="예시 답변을 준비하고 있어요"><i/><i/><i/></div>}
    </div>
    <div className="chat-bottom"><div className="suggested-questions" aria-label="추천 질문">{['언제 그린 그림인가요?', '어디부터 감상하면 좋을까요?', '피카소의 대표작도 알려줘'].map(q=><button key={q} onClick={()=>ask(q)} disabled={busy}>{q}<ChevronRight size={13}/></button>)}</div><form className="chat-input" onSubmit={e=>{e.preventDefault();ask(input);}}><input value={input} onChange={e=>setInput(e.target.value)} placeholder="그림에 대해 궁금한 점을 물어보세요" aria-label="도슨트에게 질문" maxLength={500}/><button type="submit" disabled={!input.trim() || busy} aria-label="질문 보내기"><Send size={17}/></button></form><p className="chat-disclaimer">UI 목업 · 준비된 예시 답변을 보여드려요.</p></div>
    {showSources && <div className="source-popover"><div><h3><FileText size={17}/> 답변의 출처</h3><button className="text-link" onClick={()=>setShowSources(false)}>닫기</button></div><p>준비된 작품 메타데이터를 바탕으로 한 예시 답변입니다. 감상 제안은 사실 해설과 구분됩니다.</p><a href={source} target="_blank" rel="noreferrer"><span className="citation-number">1</span><div><strong>{art.titleKo}</strong><small>{sourceName} · {art.artistKo}, {art.year}</small></div><ExternalLink size={17}/></a></div>}
  </section>;
}
