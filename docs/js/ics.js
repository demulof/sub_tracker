// 產生行事曆檔（.ics），讓扣款日出現在手機行事曆，並在前一天提醒。
// 網頁版沒有伺服器可以發推播，用行事曆提醒是最穩定的替代方式。
import { cycle } from './model.js';

const pad = (n) => String(n).padStart(2, '0');
const icsDate = (d) => `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}`;
const escapeText = (s) => s.replace(/\\/g, '\\\\').replace(/;/g, '\\;').replace(/,/g, '\\,').replace(/\n/g, '\\n');

/** 依 RFC 5545 把長行折成 75 位元組以內。 */
function fold(line) {
  const bytes = new TextEncoder().encode(line);
  if (bytes.length <= 75) return line;
  const parts = [];
  let current = '';
  let size = 0;
  for (const ch of line) {
    const len = new TextEncoder().encode(ch).length;
    if (size + len > (parts.length ? 74 : 75)) {
      parts.push(current);
      current = '';
      size = 0;
    }
    current += ch;
    size += len;
  }
  parts.push(current);
  return parts.join('\r\n ');
}

/**
 * 週期規則。扣款日是 29～31 號時，用 BYSETPOS=-1 取「該月存在的最後一個候選日」，
 * 效果與 app 的規則相同（1/31 → 2/28 → 3/31）。
 */
export function rrule(sub) {
  const months = cycle(sub.cycle).months;
  const day = sub.firstPaymentDate.getDate();
  let rule = `FREQ=MONTHLY;INTERVAL=${months}`;
  if (day > 28) {
    const days = [];
    for (let d = 28; d <= day; d++) days.push(d);
    rule += `;BYMONTHDAY=${days.join(',')};BYSETPOS=-1`;
  }
  if (sub.endDate) {
    // 停止續訂日（含）之後不再扣款，所以最後可能的扣款日是前一天。
    const last = new Date(sub.endDate.getFullYear(), sub.endDate.getMonth(), sub.endDate.getDate() - 1);
    rule += `;UNTIL=${icsDate(last)}`;
  }
  return rule;
}

export function buildIcs(subs, formatAmount) {
  const now = new Date();
  const stamp = `${now.getUTCFullYear()}${pad(now.getUTCMonth() + 1)}${pad(now.getUTCDate())}T` +
    `${pad(now.getUTCHours())}${pad(now.getUTCMinutes())}${pad(now.getUTCSeconds())}Z`;
  const lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//sub_tracker//訂閱管家//ZH',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
  ];
  for (const sub of subs) {
    const start = sub.firstPaymentDate;
    const end = new Date(start.getFullYear(), start.getMonth(), start.getDate() + 1);
    const amount = formatAmount(sub.amount, sub.currency);
    lines.push(
      'BEGIN:VEVENT',
      `UID:${sub.id}@sub-tracker`,
      `DTSTAMP:${stamp}`,
      `DTSTART;VALUE=DATE:${icsDate(start)}`,
      `DTEND;VALUE=DATE:${icsDate(end)}`,
      `RRULE:${rrule(sub)}`,
      `SUMMARY:${escapeText(`${sub.name} 扣款 ${amount}`)}`,
      `DESCRIPTION:${escapeText(`${sub.plan}｜${amount} ${cycle(sub.cycle).short}\n由訂閱管家建立`)}`,
      'TRANSP:TRANSPARENT',
      'BEGIN:VALARM',
      'ACTION:DISPLAY',
      `DESCRIPTION:${escapeText(`明天 ${sub.name} 扣款 ${amount}`)}`,
      'TRIGGER:-PT15H', // 全天事件從 0 點起算，-15 小時 = 前一天早上 9 點
      'END:VALARM',
      'END:VEVENT',
    );
  }
  lines.push('END:VCALENDAR');
  return lines.map(fold).join('\r\n') + '\r\n';
}
