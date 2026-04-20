// lib/services/completions.dart
// Full snippet library + completion engine

import '../models/models.dart';

// ═══════════════════════════════════════════
//  HTML SNIPPETS
// ═══════════════════════════════════════════
const _htmlSnippets = <CompletionItem>[
  // Boilerplate
  CompletionItem(label: '!', insertText: '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Document</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  
  <script src="app.js"></script>
</body>
</html>''', kind: 'snippet', detail: 'HTML boilerplate'),

  CompletionItem(label: 'html5', insertText: '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Document</title>
</head>
<body>
  
</body>
</html>''', kind: 'snippet', detail: 'HTML5 skeleton'),

  // Structural
  CompletionItem(label: 'div', insertText: '<div class="">\n  \n</div>', kind: 'tag', detail: 'div element'),
  CompletionItem(label: 'divid', insertText: '<div id="">\n  \n</div>', kind: 'tag', detail: 'div with id'),
  CompletionItem(label: 'section', insertText: '<section>\n  \n</section>', kind: 'tag'),
  CompletionItem(label: 'article', insertText: '<article>\n  \n</article>', kind: 'tag'),
  CompletionItem(label: 'nav', insertText: '<nav>\n  \n</nav>', kind: 'tag'),
  CompletionItem(label: 'header', insertText: '<header>\n  \n</header>', kind: 'tag'),
  CompletionItem(label: 'footer', insertText: '<footer>\n  \n</footer>', kind: 'tag'),
  CompletionItem(label: 'main', insertText: '<main>\n  \n</main>', kind: 'tag'),
  CompletionItem(label: 'aside', insertText: '<aside>\n  \n</aside>', kind: 'tag'),

  // Typography
  CompletionItem(label: 'h1', insertText: '<h1></h1>', kind: 'tag'),
  CompletionItem(label: 'h2', insertText: '<h2></h2>', kind: 'tag'),
  CompletionItem(label: 'h3', insertText: '<h3></h3>', kind: 'tag'),
  CompletionItem(label: 'p', insertText: '<p></p>', kind: 'tag'),
  CompletionItem(label: 'span', insertText: '<span></span>', kind: 'tag'),
  CompletionItem(label: 'strong', insertText: '<strong></strong>', kind: 'tag'),
  CompletionItem(label: 'em', insertText: '<em></em>', kind: 'tag'),
  CompletionItem(label: 'br', insertText: '<br>', kind: 'tag'),
  CompletionItem(label: 'hr', insertText: '<hr>', kind: 'tag'),

  // Links & Media
  CompletionItem(label: 'a', insertText: '<a href=""></a>', kind: 'tag'),
  CompletionItem(label: 'img', insertText: '<img src="" alt="" loading="lazy">', kind: 'tag'),
  CompletionItem(label: 'video', insertText: '<video src="" controls>\n  Your browser does not support video.\n</video>', kind: 'tag'),
  CompletionItem(label: 'audio', insertText: '<audio src="" controls></audio>', kind: 'tag'),
  CompletionItem(label: 'iframe', insertText: '<iframe src="" width="100%" height="400" frameborder="0"></iframe>', kind: 'tag'),

  // Forms
  CompletionItem(label: 'form', insertText: '<form action="" method="post">\n  \n  <button type="submit">Submit</button>\n</form>', kind: 'tag'),
  CompletionItem(label: 'input', insertText: '<input type="text" name="" id="" placeholder="">', kind: 'tag'),
  CompletionItem(label: 'inputemail', insertText: '<input type="email" name="email" id="email" required>', kind: 'tag'),
  CompletionItem(label: 'inputpassword', insertText: '<input type="password" name="password" id="password" required>', kind: 'tag'),
  CompletionItem(label: 'inputnumber', insertText: '<input type="number" name="" id="" min="" max="" step="1">', kind: 'tag'),
  CompletionItem(label: 'inputfile', insertText: '<input type="file" name="" id="" accept="">', kind: 'tag'),
  CompletionItem(label: 'textarea', insertText: '<textarea name="" id="" rows="4" placeholder=""></textarea>', kind: 'tag'),
  CompletionItem(label: 'select', insertText: '<select name="" id="">\n  <option value="">Select...</option>\n  <option value="1">Option 1</option>\n</select>', kind: 'tag'),
  CompletionItem(label: 'label', insertText: '<label for=""></label>', kind: 'tag'),
  CompletionItem(label: 'button', insertText: '<button type="button"></button>', kind: 'tag'),
  CompletionItem(label: 'btnsubmit', insertText: '<button type="submit" class="btn btn-primary">Submit</button>', kind: 'snippet'),
  CompletionItem(label: 'fieldset', insertText: '<fieldset>\n  <legend></legend>\n  \n</fieldset>', kind: 'tag'),

  // Lists & Tables
  CompletionItem(label: 'ul', insertText: '<ul>\n  <li></li>\n  <li></li>\n</ul>', kind: 'tag'),
  CompletionItem(label: 'ol', insertText: '<ol>\n  <li></li>\n  <li></li>\n</ol>', kind: 'tag'),
  CompletionItem(label: 'li', insertText: '<li></li>', kind: 'tag'),
  CompletionItem(label: 'table', insertText: '<table>\n  <thead>\n    <tr>\n      <th>Header</th>\n    </tr>\n  </thead>\n  <tbody>\n    <tr>\n      <td>Data</td>\n    </tr>\n  </tbody>\n</table>', kind: 'tag'),
  CompletionItem(label: 'dl', insertText: '<dl>\n  <dt>Term</dt>\n  <dd>Description</dd>\n</dl>', kind: 'tag'),

  // Meta & Head
  CompletionItem(label: 'meta', insertText: '<meta name="" content="">', kind: 'tag'),
  CompletionItem(label: 'link', insertText: '<link rel="stylesheet" href="">', kind: 'tag'),
  CompletionItem(label: 'script', insertText: '<script src=""></script>', kind: 'tag'),
  CompletionItem(label: 'scripti', insertText: '<script>\n  \n</script>', kind: 'snippet', detail: 'inline script'),
  CompletionItem(label: 'style', insertText: '<style>\n  \n</style>', kind: 'tag'),
  CompletionItem(label: 'metaog', insertText: '<meta property="og:title" content="">\n<meta property="og:description" content="">\n<meta property="og:image" content="">', kind: 'snippet', detail: 'Open Graph meta'),
  CompletionItem(label: 'metaviewport', insertText: '<meta name="viewport" content="width=device-width, initial-scale=1.0">', kind: 'snippet'),

  // Semantic
  CompletionItem(label: 'figure', insertText: '<figure>\n  <img src="" alt="">\n  <figcaption></figcaption>\n</figure>', kind: 'tag'),
  CompletionItem(label: 'details', insertText: '<details>\n  <summary></summary>\n  \n</details>', kind: 'tag'),
  CompletionItem(label: 'dialog', insertText: '<dialog id="">\n  \n  <button onclick="this.closest(\'dialog\').close()">Close</button>\n</dialog>', kind: 'tag'),
  CompletionItem(label: 'canvas', insertText: '<canvas id="" width="800" height="600"></canvas>', kind: 'tag'),
  CompletionItem(label: 'svg', insertText: '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">\n  \n</svg>', kind: 'tag'),

  // Attributes
  CompletionItem(label: 'class', insertText: 'class=""', kind: 'attr'),
  CompletionItem(label: 'id', insertText: 'id=""', kind: 'attr'),
  CompletionItem(label: 'style', insertText: 'style=""', kind: 'attr'),
  CompletionItem(label: 'data', insertText: 'data-=""', kind: 'attr'),
  CompletionItem(label: 'aria', insertText: 'aria-label=""', kind: 'attr'),
  CompletionItem(label: 'onclick', insertText: 'onclick=""', kind: 'attr'),
];

// ═══════════════════════════════════════════
//  CSS SNIPPETS
// ═══════════════════════════════════════════
const _cssSnippets = <CompletionItem>[
  // Reset/Base
  CompletionItem(label: 'reset', insertText: '''*, *::before, *::after {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}''', kind: 'snippet', detail: 'CSS reset'),

  CompletionItem(label: 'root', insertText: ''':root {
  --color-primary: #3b82f6;
  --color-bg: #080b14;
  --color-text: #e2e8f4;
  --font-mono: 'JetBrains Mono', monospace;
  --font-sans: 'Inter', system-ui, sans-serif;
  --radius: 8px;
  --shadow: 0 4px 24px rgba(0,0,0,0.4);
}''', kind: 'snippet', detail: 'CSS custom properties'),

  // Layout
  CompletionItem(label: 'flex', insertText: 'display: flex;\nalign-items: center;\njustify-content: center;', kind: 'snippet'),
  CompletionItem(label: 'flexcol', insertText: 'display: flex;\nflex-direction: column;\ngap: 1rem;', kind: 'snippet'),
  CompletionItem(label: 'flexbetween', insertText: 'display: flex;\nalign-items: center;\njustify-content: space-between;', kind: 'snippet'),
  CompletionItem(label: 'grid', insertText: 'display: grid;\ngrid-template-columns: repeat(auto-fit, minmax(280px, 1fr));\ngap: 1.5rem;', kind: 'snippet'),
  CompletionItem(label: 'grid2', insertText: 'display: grid;\ngrid-template-columns: 1fr 1fr;\ngap: 1rem;', kind: 'snippet'),
  CompletionItem(label: 'grid3', insertText: 'display: grid;\ngrid-template-columns: repeat(3, 1fr);\ngap: 1rem;', kind: 'snippet'),
  CompletionItem(label: 'center', insertText: 'position: absolute;\ntop: 50%;\nleft: 50%;\ntransform: translate(-50%, -50%);', kind: 'snippet'),
  CompletionItem(label: 'centerflex', insertText: 'display: flex;\nalign-items: center;\njustify-content: center;\nmin-height: 100vh;', kind: 'snippet'),
  CompletionItem(label: 'sticky', insertText: 'position: sticky;\ntop: 0;\nz-index: 100;', kind: 'snippet'),
  CompletionItem(label: 'fixed', insertText: 'position: fixed;\ntop: 0;\nleft: 0;\nright: 0;\nz-index: 1000;', kind: 'snippet'),
  CompletionItem(label: 'overlay', insertText: 'position: fixed;\ntop: 0;\nleft: 0;\nright: 0;\nbottom: 0;\nbackground: rgba(0,0,0,0.5);\nz-index: 500;', kind: 'snippet'),
  CompletionItem(label: 'container', insertText: '''width: 100%;
max-width: 1200px;
margin: 0 auto;
padding: 0 1.5rem;''', kind: 'snippet'),

  // Visual
  CompletionItem(label: 'gradient', insertText: 'background: linear-gradient(135deg, #3b82f6 0%, #8b5cf6 100%);', kind: 'snippet'),
  CompletionItem(label: 'gradienttext', insertText: 'background: linear-gradient(135deg, #3b82f6, #8b5cf6);\n-webkit-background-clip: text;\n-webkit-text-fill-color: transparent;\nbackground-clip: text;', kind: 'snippet'),
  CompletionItem(label: 'shadow', insertText: 'box-shadow: 0 4px 24px rgba(0, 0, 0, 0.15);', kind: 'snippet'),
  CompletionItem(label: 'shadowlg', insertText: 'box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);', kind: 'snippet'),
  CompletionItem(label: 'glass', insertText: 'background: rgba(255, 255, 255, 0.05);\nbackdrop-filter: blur(12px);\n-webkit-backdrop-filter: blur(12px);\nborder: 1px solid rgba(255,255,255,0.1);', kind: 'snippet'),
  CompletionItem(label: 'transition', insertText: 'transition: all 0.2s ease;', kind: 'snippet'),
  CompletionItem(label: 'transitionfast', insertText: 'transition: all 0.15s cubic-bezier(0.4, 0, 0.2, 1);', kind: 'snippet'),
  CompletionItem(label: 'hover', insertText: ':hover {\n  \n}', kind: 'snippet'),
  CompletionItem(label: 'animation', insertText: '@keyframes fadeIn {\n  from { opacity: 0; transform: translateY(10px); }\n  to   { opacity: 1; transform: translateY(0); }\n}\n\n.element {\n  animation: fadeIn 0.3s ease;\n}', kind: 'snippet'),
  CompletionItem(label: 'spin', insertText: '@keyframes spin {\n  from { transform: rotate(0deg); }\n  to   { transform: rotate(360deg); }\n}\n\n.spinner {\n  animation: spin 1s linear infinite;\n}', kind: 'snippet'),

  // Properties
  CompletionItem(label: 'display', insertText: 'display: ', kind: 'prop'),
  CompletionItem(label: 'position', insertText: 'position: ', kind: 'prop'),
  CompletionItem(label: 'background', insertText: 'background: ', kind: 'prop'),
  CompletionItem(label: 'background-color', insertText: 'background-color: ', kind: 'prop'),
  CompletionItem(label: 'color', insertText: 'color: ', kind: 'prop'),
  CompletionItem(label: 'font-size', insertText: 'font-size: ', kind: 'prop'),
  CompletionItem(label: 'font-weight', insertText: 'font-weight: ', kind: 'prop'),
  CompletionItem(label: 'font-family', insertText: 'font-family: ', kind: 'prop'),
  CompletionItem(label: 'line-height', insertText: 'line-height: ', kind: 'prop'),
  CompletionItem(label: 'letter-spacing', insertText: 'letter-spacing: ', kind: 'prop'),
  CompletionItem(label: 'text-align', insertText: 'text-align: ', kind: 'prop'),
  CompletionItem(label: 'text-transform', insertText: 'text-transform: ', kind: 'prop'),
  CompletionItem(label: 'text-decoration', insertText: 'text-decoration: ', kind: 'prop'),
  CompletionItem(label: 'width', insertText: 'width: ', kind: 'prop'),
  CompletionItem(label: 'height', insertText: 'height: ', kind: 'prop'),
  CompletionItem(label: 'min-width', insertText: 'min-width: ', kind: 'prop'),
  CompletionItem(label: 'max-width', insertText: 'max-width: ', kind: 'prop'),
  CompletionItem(label: 'min-height', insertText: 'min-height: ', kind: 'prop'),
  CompletionItem(label: 'margin', insertText: 'margin: ', kind: 'prop'),
  CompletionItem(label: 'padding', insertText: 'padding: ', kind: 'prop'),
  CompletionItem(label: 'border', insertText: 'border: ', kind: 'prop'),
  CompletionItem(label: 'border-radius', insertText: 'border-radius: ', kind: 'prop'),
  CompletionItem(label: 'overflow', insertText: 'overflow: ', kind: 'prop'),
  CompletionItem(label: 'opacity', insertText: 'opacity: ', kind: 'prop'),
  CompletionItem(label: 'z-index', insertText: 'z-index: ', kind: 'prop'),
  CompletionItem(label: 'cursor', insertText: 'cursor: pointer;', kind: 'prop'),
  CompletionItem(label: 'user-select', insertText: 'user-select: none;', kind: 'prop'),
  CompletionItem(label: 'pointer-events', insertText: 'pointer-events: none;', kind: 'prop'),
  CompletionItem(label: 'transform', insertText: 'transform: ', kind: 'prop'),
  CompletionItem(label: 'gap', insertText: 'gap: ', kind: 'prop'),
  CompletionItem(label: 'flex-direction', insertText: 'flex-direction: ', kind: 'prop'),
  CompletionItem(label: 'align-items', insertText: 'align-items: ', kind: 'prop'),
  CompletionItem(label: 'justify-content', insertText: 'justify-content: ', kind: 'prop'),
  CompletionItem(label: 'flex-wrap', insertText: 'flex-wrap: wrap;', kind: 'prop'),
  CompletionItem(label: 'grid-template-columns', insertText: 'grid-template-columns: ', kind: 'prop'),
  CompletionItem(label: 'object-fit', insertText: 'object-fit: cover;', kind: 'prop'),

  // Media queries
  CompletionItem(label: 'mq', insertText: '@media (max-width: 768px) {\n  \n}', kind: 'snippet', detail: 'media query mobile'),
  CompletionItem(label: 'mqtablet', insertText: '@media (max-width: 1024px) {\n  \n}', kind: 'snippet'),
  CompletionItem(label: 'mqdark', insertText: '@media (prefers-color-scheme: dark) {\n  \n}', kind: 'snippet'),
  CompletionItem(label: 'mqmotion', insertText: '@media (prefers-reduced-motion: reduce) {\n  \n}', kind: 'snippet'),

  // Functions
  CompletionItem(label: 'rgba', insertText: 'rgba()', kind: 'fn'),
  CompletionItem(label: 'hsl', insertText: 'hsl()', kind: 'fn'),
  CompletionItem(label: 'calc', insertText: 'calc()', kind: 'fn'),
  CompletionItem(label: 'var', insertText: 'var(--)', kind: 'fn'),
  CompletionItem(label: 'clamp', insertText: 'clamp(1rem, 2.5vw, 2rem)', kind: 'fn'),
  CompletionItem(label: 'min', insertText: 'min(100%, 1200px)', kind: 'fn'),
];

// ═══════════════════════════════════════════
//  JS SNIPPETS
// ═══════════════════════════════════════════
const _jsSnippets = <CompletionItem>[
  // Variables
  CompletionItem(label: 'const', insertText: 'const ', kind: 'keyword'),
  CompletionItem(label: 'let', insertText: 'let ', kind: 'keyword'),
  CompletionItem(label: 'var', insertText: 'var ', kind: 'keyword'),

  // Functions
  CompletionItem(label: 'fn', insertText: 'function () {\n  \n}', kind: 'snippet', detail: 'function declaration'),
  CompletionItem(label: 'function', insertText: 'function () {\n  \n}', kind: 'keyword'),
  CompletionItem(label: 'arrow', insertText: '() => {\n  \n}', kind: 'snippet'),
  CompletionItem(label: 'afn', insertText: 'async function () {\n  \n}', kind: 'snippet', detail: 'async function'),
  CompletionItem(label: 'aarrow', insertText: 'async () => {\n  \n}', kind: 'snippet', detail: 'async arrow'),
  CompletionItem(label: 'iife', insertText: '(() => {\n  \n})();', kind: 'snippet', detail: 'IIFE'),
  CompletionItem(label: 'cb', insertText: '(err, result) => {\n  if (err) { console.error(err); return; }\n  \n}', kind: 'snippet', detail: 'callback'),

  // Control flow
  CompletionItem(label: 'if', insertText: 'if () {\n  \n}', kind: 'keyword'),
  CompletionItem(label: 'ifelse', insertText: 'if () {\n  \n} else {\n  \n}', kind: 'snippet'),
  CompletionItem(label: 'ternary', insertText: ' ?  : ', kind: 'snippet'),
  CompletionItem(label: 'for', insertText: 'for (let i = 0; i < ; i++) {\n  \n}', kind: 'keyword'),
  CompletionItem(label: 'forof', insertText: 'for (const  of ) {\n  \n}', kind: 'snippet'),
  CompletionItem(label: 'forin', insertText: 'for (const key in ) {\n  \n}', kind: 'snippet'),
  CompletionItem(label: 'while', insertText: 'while () {\n  \n}', kind: 'keyword'),
  CompletionItem(label: 'switch', insertText: 'switch () {\n  case :\n    \n    break;\n  default:\n    \n}', kind: 'keyword'),

  // Error handling
  CompletionItem(label: 'try', insertText: 'try {\n  \n} catch (error) {\n  console.error(error);\n}', kind: 'keyword'),
  CompletionItem(label: 'trycf', insertText: 'try {\n  \n} catch (error) {\n  console.error(error);\n} finally {\n  \n}', kind: 'snippet'),
  CompletionItem(label: 'throw', insertText: 'throw new Error(\'\');', kind: 'keyword'),

  // Classes
  CompletionItem(label: 'class', insertText: 'class  {\n  constructor() {\n    \n  }\n}', kind: 'keyword'),
  CompletionItem(label: 'classex', insertText: 'class  extends  {\n  constructor() {\n    super();\n    \n  }\n}', kind: 'snippet'),

  // Async
  CompletionItem(label: 'promise', insertText: 'new Promise((resolve, reject) => {\n  \n});', kind: 'snippet'),
  CompletionItem(label: 'then', insertText: '.then(result => {\n  \n}).catch(err => {\n  console.error(err);\n});', kind: 'method'),
  CompletionItem(label: 'await', insertText: 'await ', kind: 'keyword'),
  CompletionItem(label: 'fetch', insertText: "const response = await fetch('');\nconst data = await response.json();\nconsole.log(data);", kind: 'snippet'),
  CompletionItem(label: 'fetchpost', insertText: "const response = await fetch('', {\n  method: 'POST',\n  headers: { 'Content-Type': 'application/json' },\n  body: JSON.stringify({})\n});\nconst data = await response.json();", kind: 'snippet'),

  // DOM
  CompletionItem(label: 'qs', insertText: 'document.querySelector(\'\')', kind: 'method', detail: 'querySelector'),
  CompletionItem(label: 'qsa', insertText: 'document.querySelectorAll(\'\')', kind: 'method', detail: 'querySelectorAll'),
  CompletionItem(label: 'getel', insertText: "document.getElementById('')", kind: 'method'),
  CompletionItem(label: 'create', insertText: "document.createElement('')", kind: 'method'),
  CompletionItem(label: 'on', insertText: "addEventListener('', () => {\n  \n});", kind: 'method'),
  CompletionItem(label: 'click', insertText: "addEventListener('click', () => {\n  \n});", kind: 'snippet'),
  CompletionItem(label: 'dce', insertText: "document.addEventListener('DOMContentLoaded', () => {\n  \n});", kind: 'snippet', detail: 'DOMContentLoaded'),
  CompletionItem(label: 'cl', insertText: 'classList', kind: 'method'),
  CompletionItem(label: 'toggle', insertText: ".classList.toggle('')", kind: 'method'),
  CompletionItem(label: 'add', insertText: ".classList.add('')", kind: 'method'),
  CompletionItem(label: 'remove', insertText: ".classList.remove('')", kind: 'method'),

  // Arrays
  CompletionItem(label: 'map', insertText: '.map(item => )', kind: 'method'),
  CompletionItem(label: 'filter', insertText: '.filter(item => )', kind: 'method'),
  CompletionItem(label: 'reduce', insertText: '.reduce((acc, cur) => acc + cur, 0)', kind: 'method'),
  CompletionItem(label: 'find', insertText: '.find(item => )', kind: 'method'),
  CompletionItem(label: 'findindex', insertText: '.findIndex(item => )', kind: 'method'),
  CompletionItem(label: 'foreach', insertText: '.forEach(item => {\n  \n})', kind: 'method'),
  CompletionItem(label: 'some', insertText: '.some(item => )', kind: 'method'),
  CompletionItem(label: 'every', insertText: '.every(item => )', kind: 'method'),
  CompletionItem(label: 'includes', insertText: '.includes()', kind: 'method'),
  CompletionItem(label: 'flat', insertText: '.flat()', kind: 'method'),
  CompletionItem(label: 'spread', insertText: '[...]', kind: 'snippet'),
  CompletionItem(label: 'afrom', insertText: 'Array.from()', kind: 'method'),

  // Objects
  CompletionItem(label: 'keys', insertText: 'Object.keys()', kind: 'method'),
  CompletionItem(label: 'values', insertText: 'Object.values()', kind: 'method'),
  CompletionItem(label: 'entries', insertText: 'Object.entries()', kind: 'method'),
  CompletionItem(label: 'assign', insertText: 'Object.assign({}, )', kind: 'method'),
  CompletionItem(label: 'destruct', insertText: 'const { , } = ;', kind: 'snippet'),
  CompletionItem(label: 'spread2', insertText: '{ ...}', kind: 'snippet'),

  // Console
  CompletionItem(label: 'cl', insertText: 'console.log()', kind: 'method'),
  CompletionItem(label: 'clg', insertText: 'console.log()', kind: 'method'),
  CompletionItem(label: 'ce', insertText: 'console.error()', kind: 'method'),
  CompletionItem(label: 'cw', insertText: 'console.warn()', kind: 'method'),
  CompletionItem(label: 'ci', insertText: 'console.info()', kind: 'method'),
  CompletionItem(label: 'ct', insertText: 'console.table()', kind: 'method'),
  CompletionItem(label: 'ctime', insertText: "console.time('');\n\nconsole.timeEnd('');", kind: 'snippet'),

  // JSON
  CompletionItem(label: 'jstr', insertText: 'JSON.stringify(, null, 2)', kind: 'method'),
  CompletionItem(label: 'jparse', insertText: 'JSON.parse()', kind: 'method'),

  // Storage
  CompletionItem(label: 'lsset', insertText: "localStorage.setItem('', JSON.stringify())", kind: 'snippet'),
  CompletionItem(label: 'lsget', insertText: "JSON.parse(localStorage.getItem('') || 'null')", kind: 'snippet'),
  CompletionItem(label: 'ssset', insertText: "sessionStorage.setItem('', JSON.stringify())", kind: 'snippet'),

  // Timers
  CompletionItem(label: 'setTimeout', insertText: "setTimeout(() => {\n  \n}, 1000);", kind: 'fn'),
  CompletionItem(label: 'setInterval', insertText: "const timer = setInterval(() => {\n  \n}, 1000);", kind: 'fn'),
  CompletionItem(label: 'raf', insertText: "requestAnimationFrame(() => {\n  \n});", kind: 'snippet', detail: 'requestAnimationFrame'),

  // Math
  CompletionItem(label: 'mfloor', insertText: 'Math.floor()', kind: 'method'),
  CompletionItem(label: 'mceil', insertText: 'Math.ceil()', kind: 'method'),
  CompletionItem(label: 'mround', insertText: 'Math.round()', kind: 'method'),
  CompletionItem(label: 'mrandom', insertText: 'Math.random()', kind: 'method'),
  CompletionItem(label: 'mmax', insertText: 'Math.max()', kind: 'method'),
  CompletionItem(label: 'mmin', insertText: 'Math.min()', kind: 'method'),
  CompletionItem(label: 'mabs', insertText: 'Math.abs()', kind: 'method'),
  CompletionItem(label: 'pi', insertText: 'Math.PI', kind: 'method'),

  // String
  CompletionItem(label: 'trim', insertText: '.trim()', kind: 'method'),
  CompletionItem(label: 'split', insertText: ".split('')", kind: 'method'),
  CompletionItem(label: 'join', insertText: ".join('')", kind: 'method'),
  CompletionItem(label: 'slice', insertText: '.slice(0, )', kind: 'method'),
  CompletionItem(label: 'replace', insertText: ".replace('', '')", kind: 'method'),
  CompletionItem(label: 'replaceall', insertText: ".replaceAll('', '')", kind: 'method'),
  CompletionItem(label: 'tolower', insertText: '.toLowerCase()', kind: 'method'),
  CompletionItem(label: 'toupper', insertText: '.toUpperCase()', kind: 'method'),
  CompletionItem(label: 'padstart', insertText: ".padStart(2, '0')", kind: 'method'),
  CompletionItem(label: 'template', insertText: '`\${}`', kind: 'snippet'),

  // Modern JS
  CompletionItem(label: 'import', insertText: "import  from '';", kind: 'keyword'),
  CompletionItem(label: 'export', insertText: 'export ', kind: 'keyword'),
  CompletionItem(label: 'exportd', insertText: 'export default ', kind: 'keyword'),
  CompletionItem(label: 'nullish', insertText: ' ?? ', kind: 'op'),
  CompletionItem(label: 'optional', insertText: '?.', kind: 'op'),
  CompletionItem(label: 'typeof', insertText: 'typeof ', kind: 'keyword'),
  CompletionItem(label: 'instanceof', insertText: 'instanceof ', kind: 'keyword'),
  CompletionItem(label: 'null', insertText: 'null', kind: 'keyword'),
  CompletionItem(label: 'undefined', insertText: 'undefined', kind: 'keyword'),
  CompletionItem(label: 'true', insertText: 'true', kind: 'keyword'),
  CompletionItem(label: 'false', insertText: 'false', kind: 'keyword'),

  // Patterns
  CompletionItem(label: 'singleton', insertText: '''const  = (() => {
  let instance;
  return {
    getInstance() {
      if (!instance) instance = {};
      return instance;
    }
  };
})();''', kind: 'snippet', detail: 'Singleton pattern'),

  CompletionItem(label: 'observer', insertText: '''class EventEmitter {
  constructor() { this.events = {}; }
  on(event, cb) { (this.events[event] = this.events[event] || []).push(cb); }
  off(event, cb) { this.events[event] = (this.events[event]||[]).filter(f=>f!==cb); }
  emit(event, ...args) { (this.events[event]||[]).forEach(cb=>cb(...args)); }
}''', kind: 'snippet', detail: 'Observer/EventEmitter'),

  CompletionItem(label: 'debounce', insertText: '''function debounce(fn, delay) {
  let timer;
  return (...args) => {
    clearTimeout(timer);
    timer = setTimeout(() => fn(...args), delay);
  };
}''', kind: 'snippet'),

  CompletionItem(label: 'throttle', insertText: '''function throttle(fn, limit) {
  let inThrottle;
  return (...args) => {
    if (!inThrottle) {
      fn(...args);
      inThrottle = true;
      setTimeout(() => inThrottle = false, limit);
    }
  };
}''', kind: 'snippet'),

  CompletionItem(label: 'deepclone', insertText: 'JSON.parse(JSON.stringify())', kind: 'snippet'),
  CompletionItem(label: 'deepequal', insertText: "JSON.stringify(a) === JSON.stringify(b)", kind: 'snippet'),

  CompletionItem(label: 'uuid', insertText: "crypto.randomUUID()", kind: 'snippet', detail: 'Generate UUID'),
  CompletionItem(label: 'rand', insertText: "Math.floor(Math.random() * ) + ", kind: 'snippet', detail: 'Random number in range'),
];

// ═══════════════════════════════════════════
//  COMPLETION ENGINE
// ═══════════════════════════════════════════
class CompletionEngine {
  static List<CompletionItem> getSuggestions({
    required Language lang,
    required String word,
    required String lineContent,
    int maxResults = 12,
  }) {
    if (word.length < 1) return [];

    List<CompletionItem> pool;
    switch (lang) {
      case Language.html: pool = _htmlSnippets; break;
      case Language.css:  pool = _cssSnippets;  break;
      case Language.js:
      case Language.ts:   pool = _jsSnippets;   break;
      default:            return [];
    }

    final wLower = word.toLowerCase();

    // Score: exact start > contains > fuzzy
    final scored = <MapEntry<CompletionItem, int>>[];
    for (final item in pool) {
      final lbl = item.label.toLowerCase();
      if (lbl == word) continue; // exact match already typed
      int score = 0;
      if (lbl.startsWith(wLower)) {
        score = 100 + (100 - lbl.length); // prefer shorter labels
      } else if (lbl.contains(wLower)) {
        score = 50;
      } else {
        // Fuzzy: all chars of word in order
        int li = 0;
        bool match = true;
        for (int i = 0; i < wLower.length && li < lbl.length; i++) {
          final idx = lbl.indexOf(wLower[i], li);
          if (idx < 0) { match = false; break; }
          li = idx + 1;
        }
        if (match) score = 10;
      }
      if (score > 0) scored.add(MapEntry(item, score));
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(maxResults).map((e) => e.key).toList();
  }

  static String getInsertText(CompletionItem item, String word) {
    // Replace item from start of typed word
    return item.insertText;
  }
}
