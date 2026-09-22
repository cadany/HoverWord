/* HoverWord cookie-consent banner (Google Consent Mode v2)
 *
 * - 各页面在 gtag.js 之前的内联脚本中已将 analytics_storage 默认设为 denied
 *   （回访用户若曾同意，内联脚本直接以 granted 作为默认值，避免闪烁与竞态）
 * - 用户选择持久化在 localStorage 'hw-consent'：'granted' | 'denied'
 * - 仅在未做出选择时展示横幅；拒绝则保持默认 denied，不上报分析数据
 * - 文案跟随站点语言：读取 localStorage 'hw-lang'，并监听 'hw:lang' 事件
 */
(function () {
  var CONSENT_KEY = 'hw-consent';
  var LANG_KEY = 'hw-lang';

  var TEXT = {
    en: {
      msg: 'This site uses Google Analytics cookies — only after you agree — to understand how pages are used. The HoverWord app itself collects nothing.',
      accept: 'Accept',
      decline: 'Decline'
    },
    zh: {
      msg: '本站仅在您同意后使用 Google Analytics Cookie 统计页面访问情况。HoverWord 应用本身不收集任何数据。',
      accept: '接受',
      decline: '拒绝'
    }
  };

  function lang() {
    try {
      var saved = localStorage.getItem(LANG_KEY);
      if (saved === 'zh' || saved === 'en') return saved;
    } catch (e) {}
    return 'en';
  }

  function stored() {
    try { return localStorage.getItem(CONSENT_KEY); } catch (e) { return null; }
  }

  function grantAnalytics() {
    if (typeof gtag === 'function') {
      gtag('consent', 'update', {
        'analytics_storage': 'granted',
        'ad_storage': 'denied',
        'ad_user_data': 'denied',
        'ad_personalization': 'denied'
      });
    }
  }

  var banner = null;

  function applyText() {
    if (!banner) return;
    var t = TEXT[lang()];
    banner.querySelector('.hw-consent-msg').textContent = t.msg;
    banner.querySelector('.hw-consent-accept').textContent = t.accept;
    banner.querySelector('.hw-consent-decline').textContent = t.decline;
  }

  function close(choice) {
    try { localStorage.setItem(CONSENT_KEY, choice); } catch (e) {}
    if (choice === 'granted') grantAnalytics();
    if (banner) {
      banner.remove();
      banner = null;
    }
  }

  function build() {
    banner = document.createElement('div');
    banner.className = 'hw-consent';
    banner.setAttribute('role', 'dialog');
    banner.setAttribute('aria-label', 'Cookie consent');
    banner.innerHTML =
      '<p class="hw-consent-msg"></p>' +
      '<div class="hw-consent-actions">' +
        '<button type="button" class="hw-consent-accept"></button>' +
        '<button type="button" class="hw-consent-decline"></button>' +
      '</div>';
    banner.querySelector('.hw-consent-accept').addEventListener('click', function () { close('granted'); });
    banner.querySelector('.hw-consent-decline').addEventListener('click', function () { close('denied'); });
    applyText();
    document.body.appendChild(banner);
  }

  var style = document.createElement('style');
  style.textContent =
    '.hw-consent{position:fixed;left:12px;right:12px;bottom:12px;z-index:100;max-width:620px;margin:0 auto;' +
    'display:flex;align-items:center;gap:14px;padding:9px 16px;border-radius:12px;' +
    'border:1px solid rgba(17,17,17,0.14);background:rgba(255,255,255,0.9);' +
    '-webkit-backdrop-filter:saturate(180%) blur(20px);backdrop-filter:saturate(180%) blur(20px);' +
    'box-shadow:0 2px 6px rgba(17,17,17,0.06),0 16px 40px rgba(17,17,17,0.12);' +
    'font-family:-apple-system,BlinkMacSystemFont,"SF Pro Text","PingFang SC","Helvetica Neue","Microsoft YaHei",sans-serif;' +
    'animation:hw-consent-in .4s ease}' +
    '@media (prefers-color-scheme:dark){' +
      '.hw-consent{border-color:rgba(255,255,255,0.14);background:rgba(46,48,52,0.92);' +
      'box-shadow:0 2px 6px rgba(0,0,0,0.4),0 20px 48px rgba(0,0,0,0.5)}}' +
    '@keyframes hw-consent-in{from{opacity:0;transform:translateY(12px)}to{opacity:1;transform:none}}' +
    '@media (prefers-reduced-motion:reduce){.hw-consent{animation:none}}' +
    '.hw-consent-msg{margin:0;flex:1;font-size:12px;line-height:1.5;color:rgba(17,17,17,0.75)}' +
    '@media (prefers-color-scheme:dark){.hw-consent-msg{color:rgba(245,246,247,0.8)}}' +
    '.hw-consent-actions{display:flex;align-items:center;gap:8px;flex-shrink:0}' +
    '.hw-consent-accept,.hw-consent-decline{border:0;cursor:pointer;height:27px;padding:0 14px;' +
    'border-radius:999px;font-size:12px;font-weight:600;font-family:inherit;' +
    'transition:background-color .15s ease,border-color .15s ease,color .15s ease,transform .1s ease}' +
    '.hw-consent-accept{background:#0A6B54;color:#fff}' +
    '.hw-consent-accept:hover{background:#0A4A3A}' +
    '.hw-consent-accept:active{transform:scale(0.97)}' +
    '.hw-consent-decline{background:transparent;border:1px solid rgba(17,17,17,0.2);color:rgba(17,17,17,0.7)}' +
    '.hw-consent-decline:hover{border-color:rgba(17,17,17,0.4);color:rgba(17,17,17,0.95)}' +
    '@media (prefers-color-scheme:dark){' +
      '.hw-consent-accept{background:#2FD0A0;color:#0E0F11}' +
      '.hw-consent-accept:hover{background:#4EDFB2}' +
      '.hw-consent-decline{border-color:rgba(255,255,255,0.25);color:rgba(245,246,247,0.75)}' +
      '.hw-consent-decline:hover{border-color:rgba(255,255,255,0.45);color:#F5F6F7}}' +
    '@media (max-width:640px){.hw-consent{flex-direction:column;align-items:stretch;gap:8px}' +
      '.hw-consent-actions{justify-content:flex-end}}';
  document.head.appendChild(style);

  if (!stored()) build();

  document.addEventListener('hw:lang', applyText);
})();
