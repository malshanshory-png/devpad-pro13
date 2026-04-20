// lib/services/sample_projects.dart
// Large complete sample projects for testing

class SampleProject {
  final String name;
  final String htmlCode;
  final String cssCode;
  final String jsCode;
  const SampleProject({
    required this.name,
    required this.htmlCode,
    required this.cssCode,
    required this.jsCode,
  });
}

// ════════════════════════════════════════════
//  PROJECT 1: Todo App (Complete)
// ════════════════════════════════════════════
const sampleTodoApp = SampleProject(
  name: 'Todo App',
  htmlCode: r'''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>DevPad Todo</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <div class="app">
    <header class="header">
      <div class="logo">✦ DevPad</div>
      <div class="stats" id="stats">0 tasks</div>
    </header>

    <div class="input-area">
      <input type="text" id="taskInput" placeholder="Add a new task..." autocomplete="off">
      <select id="prioritySelect">
        <option value="low">Low</option>
        <option value="medium" selected>Medium</option>
        <option value="high">High</option>
      </select>
      <button id="addBtn" onclick="addTask()">Add</button>
    </div>

    <div class="filters">
      <button class="filter-btn active" data-filter="all" onclick="setFilter(this)">All</button>
      <button class="filter-btn" data-filter="active" onclick="setFilter(this)">Active</button>
      <button class="filter-btn" data-filter="completed" onclick="setFilter(this)">Done</button>
    </div>

    <ul id="taskList" class="task-list"></ul>

    <div class="footer" id="footer">
      <span id="leftCount">0 left</span>
      <button class="clear-btn" onclick="clearCompleted()">Clear completed</button>
    </div>
  </div>
  <script src="app.js"></script>
</body>
</html>''',

  cssCode: r'''* { margin: 0; padding: 0; box-sizing: border-box; }

body {
  font-family: 'Inter', system-ui, sans-serif;
  background: #080b14;
  color: #e2e8f4;
  min-height: 100vh;
  display: flex;
  align-items: flex-start;
  justify-content: center;
  padding: 40px 16px;
}

.app {
  width: 100%;
  max-width: 560px;
}

.header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 32px;
}

.logo {
  font-size: 1.5rem;
  font-weight: 800;
  background: linear-gradient(135deg, #3b82f6, #8b5cf6);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.stats {
  font-size: 0.85rem;
  color: #4a5568;
}

.input-area {
  display: flex;
  gap: 8px;
  margin-bottom: 12px;
}

.input-area input {
  flex: 1;
  background: #111827;
  border: 1px solid #1e2a42;
  border-radius: 10px;
  padding: 12px 16px;
  color: #e2e8f4;
  font-size: 0.95rem;
  outline: none;
  transition: border-color 0.2s;
}

.input-area input:focus { border-color: #3b82f6; }
.input-area input::placeholder { color: #4a5568; }

.input-area select {
  background: #111827;
  border: 1px solid #1e2a42;
  border-radius: 10px;
  padding: 0 12px;
  color: #94a3b8;
  font-size: 0.85rem;
  outline: none;
  cursor: pointer;
}

#addBtn {
  background: #3b82f6;
  color: #fff;
  border: none;
  border-radius: 10px;
  padding: 12px 20px;
  font-size: 0.9rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
  white-space: nowrap;
}
#addBtn:hover { background: #2563eb; transform: translateY(-1px); }
#addBtn:active { transform: scale(0.95); }

.filters {
  display: flex;
  gap: 4px;
  margin-bottom: 16px;
  background: #0d1120;
  padding: 4px;
  border-radius: 10px;
}

.filter-btn {
  flex: 1;
  padding: 8px;
  border: none;
  border-radius: 7px;
  background: transparent;
  color: #4a5568;
  cursor: pointer;
  font-size: 0.85rem;
  transition: all 0.15s;
}
.filter-btn.active { background: #111827; color: #e2e8f4; }

.task-list {
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 8px;
  min-height: 80px;
}

.task-item {
  background: #111827;
  border: 1px solid #1e2a42;
  border-radius: 12px;
  padding: 14px 16px;
  display: flex;
  align-items: center;
  gap: 12px;
  animation: slideIn 0.2s ease;
  transition: all 0.2s;
}
.task-item:hover { border-color: #243050; }
.task-item.completed { opacity: 0.5; }

@keyframes slideIn {
  from { opacity: 0; transform: translateY(-8px); }
  to   { opacity: 1; transform: translateY(0); }
}

.task-check {
  width: 20px; height: 20px;
  border-radius: 50%;
  border: 2px solid #1e2a42;
  cursor: pointer;
  flex-shrink: 0;
  transition: all 0.15s;
  display: flex; align-items: center; justify-content: center;
}
.task-check:hover { border-color: #3b82f6; }
.task-check.done { background: #22d3a0; border-color: #22d3a0; color: #fff; }

.task-text {
  flex: 1;
  font-size: 0.95rem;
  transition: all 0.2s;
}
.task-item.completed .task-text {
  text-decoration: line-through;
  color: #4a5568;
}

.priority-dot {
  width: 8px; height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}
.priority-dot.high   { background: #f87171; }
.priority-dot.medium { background: #fbbf24; }
.priority-dot.low    { background: #22d3a0; }

.task-delete {
  width: 28px; height: 28px;
  border: none; background: transparent;
  color: #4a5568; cursor: pointer;
  border-radius: 6px;
  font-size: 1rem;
  transition: all 0.15s;
  display: flex; align-items: center; justify-content: center;
}
.task-delete:hover { background: rgba(248,113,113,0.1); color: #f87171; }

.footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 16px;
  padding: 12px 4px;
  font-size: 0.85rem;
  color: #4a5568;
}

.clear-btn {
  background: none;
  border: none;
  color: #4a5568;
  cursor: pointer;
  font-size: 0.85rem;
  transition: color 0.15s;
}
.clear-btn:hover { color: #f87171; }

.empty-state {
  text-align: center;
  padding: 48px 24px;
  color: #2d3748;
}
.empty-state .icon { font-size: 3rem; margin-bottom: 12px; }''',

  jsCode: r'''// DevPad Todo App

let tasks = JSON.parse(localStorage.getItem('dp_tasks') || '[]');
let filter = 'all';
let nextId = Date.now();

function saveTasks() {
  localStorage.setItem('dp_tasks', JSON.stringify(tasks));
}

function addTask() {
  const input = document.getElementById('taskInput');
  const priority = document.getElementById('prioritySelect').value;
  const text = input.value.trim();
  if (!text) {
    input.style.borderColor = '#f87171';
    setTimeout(() => input.style.borderColor = '', 800);
    return;
  }
  tasks.unshift({
    id: nextId++,
    text,
    priority,
    completed: false,
    created: Date.now()
  });
  input.value = '';
  saveTasks();
  render();
  console.info('Task added:', text);
}

function toggleTask(id) {
  const task = tasks.find(t => t.id === id);
  if (task) {
    task.completed = !task.completed;
    saveTasks();
    render();
  }
}

function deleteTask(id) {
  tasks = tasks.filter(t => t.id !== id);
  saveTasks();
  render();
}

function clearCompleted() {
  const before = tasks.length;
  tasks = tasks.filter(t => !t.completed);
  saveTasks();
  render();
  console.info(`Cleared ${before - tasks.length} completed tasks`);
}

function setFilter(btn) {
  document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');
  filter = btn.dataset.filter;
  render();
}

function getFiltered() {
  switch (filter) {
    case 'active':    return tasks.filter(t => !t.completed);
    case 'completed': return tasks.filter(t => t.completed);
    default:          return tasks;
  }
}

function render() {
  const list = document.getElementById('taskList');
  const filtered = getFiltered();
  const activeCount = tasks.filter(t => !t.completed).length;

  document.getElementById('stats').textContent = `${tasks.length} task${tasks.length !== 1 ? 's' : ''}`;
  document.getElementById('leftCount').textContent = `${activeCount} left`;

  if (filtered.length === 0) {
    list.innerHTML = `
      <div class="empty-state">
        <div class="icon">${filter === 'completed' ? '🎉' : '📝'}</div>
        <div>${filter === 'completed' ? 'No completed tasks' : 'No tasks yet!'}</div>
      </div>`;
    return;
  }

  list.innerHTML = filtered.map(task => `
    <li class="task-item ${task.completed ? 'completed' : ''}" id="task-${task.id}">
      <div class="task-check ${task.completed ? 'done' : ''}" onclick="toggleTask(${task.id})">
        ${task.completed ? '✓' : ''}
      </div>
      <div class="priority-dot ${task.priority}"></div>
      <span class="task-text">${escapeHtml(task.text)}</span>
      <button class="task-delete" onclick="deleteTask(${task.id})" title="Delete">✕</button>
    </li>
  `).join('');
}

function escapeHtml(str) {
  return str.replace(/[&<>"']/g, c => ({
    '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'
  })[c]);
}

// Handle Enter key
document.getElementById('taskInput').addEventListener('keydown', e => {
  if (e.key === 'Enter') addTask();
});

// Init
document.addEventListener('DOMContentLoaded', () => {
  render();
  console.info('✓ Todo App initialized -', tasks.length, 'tasks loaded');
});''',
);

// ════════════════════════════════════════════
//  PROJECT 2: Weather Dashboard
// ════════════════════════════════════════════
const sampleWeatherApp = SampleProject(
  name: 'Weather Dashboard',
  htmlCode: r'''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Weather Dashboard</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <div class="app">
    <div class="search-bar">
      <input type="text" id="cityInput" placeholder="Enter city name..." value="London">
      <button onclick="fetchWeather()">🔍 Search</button>
    </div>

    <div id="loading" class="loading hidden">Loading...</div>
    <div id="error" class="error hidden"></div>

    <div id="weatherCard" class="weather-card hidden">
      <div class="city-name" id="cityName"></div>
      <div class="country" id="countryName"></div>
      <div class="temp-main">
        <div class="temp" id="temp"></div>
        <div class="weather-icon" id="weatherIcon"></div>
      </div>
      <div class="description" id="desc"></div>
      <div class="details-grid">
        <div class="detail">
          <div class="detail-label">Feels Like</div>
          <div class="detail-value" id="feelsLike"></div>
        </div>
        <div class="detail">
          <div class="detail-label">Humidity</div>
          <div class="detail-value" id="humidity"></div>
        </div>
        <div class="detail">
          <div class="detail-label">Wind</div>
          <div class="detail-value" id="wind"></div>
        </div>
        <div class="detail">
          <div class="detail-label">Pressure</div>
          <div class="detail-value" id="pressure"></div>
        </div>
        <div class="detail">
          <div class="detail-label">Visibility</div>
          <div class="detail-value" id="visibility"></div>
        </div>
        <div class="detail">
          <div class="detail-label">UV Index</div>
          <div class="detail-value" id="uvIndex"></div>
        </div>
      </div>
    </div>

    <div id="forecast" class="forecast hidden"></div>
  </div>
  <script src="app.js"></script>
</body>
</html>''',

  cssCode: r'''* { margin: 0; padding: 0; box-sizing: border-box; }

body {
  font-family: 'Inter', system-ui, sans-serif;
  background: linear-gradient(135deg, #080b14 0%, #0d1a3a 100%);
  color: #e2e8f4;
  min-height: 100vh;
  padding: 24px 16px;
}

.app { max-width: 480px; margin: 0 auto; }

.search-bar {
  display: flex; gap: 8px; margin-bottom: 24px;
}
.search-bar input {
  flex: 1; background: rgba(255,255,255,0.05);
  border: 1px solid rgba(255,255,255,0.1);
  border-radius: 12px; padding: 14px 18px;
  color: #e2e8f4; font-size: 1rem; outline: none;
  transition: border-color 0.2s;
}
.search-bar input:focus { border-color: #3b82f6; }
.search-bar input::placeholder { color: rgba(255,255,255,0.3); }
.search-bar button {
  background: #3b82f6; color: #fff; border: none;
  border-radius: 12px; padding: 14px 18px;
  cursor: pointer; font-size: 0.9rem; font-weight: 600;
  transition: all 0.2s;
}
.search-bar button:hover { background: #2563eb; }

.weather-card {
  background: rgba(255,255,255,0.04);
  backdrop-filter: blur(20px);
  border: 1px solid rgba(255,255,255,0.08);
  border-radius: 24px; padding: 32px; margin-bottom: 16px;
}

.city-name { font-size: 2rem; font-weight: 800; margin-bottom: 4px; }
.country { color: #94a3b8; font-size: 0.9rem; margin-bottom: 24px; }

.temp-main {
  display: flex; align-items: center;
  justify-content: space-between; margin-bottom: 12px;
}
.temp {
  font-size: 5rem; font-weight: 300;
  background: linear-gradient(135deg, #67e8f9, #3b82f6);
  -webkit-background-clip: text; -webkit-text-fill-color: transparent;
  background-clip: text;
}
.weather-icon { font-size: 5rem; }
.description {
  text-transform: capitalize; color: #94a3b8;
  font-size: 1.1rem; margin-bottom: 28px;
}

.details-grid {
  display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 16px;
}
.detail {
  background: rgba(255,255,255,0.03);
  border: 1px solid rgba(255,255,255,0.06);
  border-radius: 12px; padding: 14px; text-align: center;
}
.detail-label { font-size: 0.7rem; color: #4a5568; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 6px; }
.detail-value { font-size: 1rem; font-weight: 600; }

.forecast {
  display: flex; gap: 10px; overflow-x: auto;
  padding-bottom: 8px; scrollbar-width: none;
}
.forecast::-webkit-scrollbar { display: none; }
.forecast-day {
  background: rgba(255,255,255,0.04);
  border: 1px solid rgba(255,255,255,0.08);
  border-radius: 16px; padding: 16px;
  text-align: center; flex-shrink: 0;
  min-width: 80px;
}
.forecast-day .day { font-size: 0.75rem; color: #4a5568; margin-bottom: 8px; }
.forecast-day .icon { font-size: 1.8rem; margin-bottom: 8px; }
.forecast-day .hi { font-size: 1rem; font-weight: 700; }
.forecast-day .lo { font-size: 0.8rem; color: #4a5568; }

.loading { text-align: center; padding: 48px; color: #4a5568; }
.error { background: rgba(248,113,113,0.1); border: 1px solid rgba(248,113,113,0.2); border-radius: 12px; padding: 16px; color: #f87171; text-align: center; }
.hidden { display: none !important; }''',

  jsCode: r'''// Weather Dashboard — uses simulated data (no API key needed)
// In production, replace with real OpenWeatherMap API calls

const WEATHER_DATA = {
  london:  { city: 'London',    country: 'UK',     temp: 12, feels: 9,  humidity: 78, wind: 18, pressure: 1012, visibility: 9, uv: 2, desc: 'partly cloudy',    icon: '⛅', forecast: [13,11,14,10,12,15,13] },
  paris:   { city: 'Paris',     country: 'France', temp: 15, feels: 13, humidity: 65, wind: 12, pressure: 1018, visibility: 12, uv: 3, desc: 'clear sky',          icon: '☀️', forecast: [16,18,15,17,14,13,16] },
  dubai:   { city: 'Dubai',     country: 'UAE',    temp: 38, feels: 42, humidity: 45, wind: 22, pressure: 1006, visibility: 10, uv: 9, desc: 'sunny and hot',       icon: '🌤', forecast: [39,37,40,38,36,38,41] },
  tokyo:   { city: 'Tokyo',     country: 'Japan',  temp: 22, feels: 21, humidity: 60, wind: 8,  pressure: 1020, visibility: 15, uv: 5, desc: 'mostly cloudy',       icon: '🌥', forecast: [23,25,21,24,22,20,23] },
  newyork: { city: 'New York',  country: 'USA',    temp: 18, feels: 16, humidity: 55, wind: 25, pressure: 1015, visibility: 14, uv: 4, desc: 'partly sunny',        icon: '⛅', forecast: [19,17,20,18,16,21,18] },
  sydney:  { city: 'Sydney',    country: 'Australia', temp: 24, feels: 23, humidity: 68, wind: 15, pressure: 1022, visibility: 20, uv: 6, desc: 'beautiful day',    icon: '☀️', forecast: [25,23,26,24,22,25,27] },
  moscow:  { city: 'Moscow',    country: 'Russia', temp: -3, feels: -8, humidity: 82, wind: 20, pressure: 1008, visibility: 6, uv: 1, desc: 'light snow',           icon: '🌨', forecast: [-2,-5,-1,-4,-6,-3,-2] },
  cairo:   { city: 'Cairo',     country: 'Egypt',  temp: 32, feels: 30, humidity: 25, wind: 10, pressure: 1014, visibility: 18, uv: 8, desc: 'sunny and dry',       icon: '☀️', forecast: [33,31,34,32,30,33,32] },
};

const DAYS = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];

function getWeatherEmoji(temp) {
  if (temp > 35) return '🌡️';
  if (temp > 25) return '☀️';
  if (temp > 15) return '⛅';
  if (temp > 5)  return '🌥';
  if (temp > -5) return '🌧';
  return '❄️';
}

async function fetchWeather() {
  const city = document.getElementById('cityInput').value.trim().toLowerCase().replace(/\s+/g,'');
  if (!city) return;

  document.getElementById('loading').classList.remove('hidden');
  document.getElementById('error').classList.add('hidden');
  document.getElementById('weatherCard').classList.add('hidden');
  document.getElementById('forecast').classList.add('hidden');

  // Simulate network delay
  await new Promise(r => setTimeout(r, 600));

  const data = WEATHER_DATA[city];

  document.getElementById('loading').classList.add('hidden');

  if (!data) {
    const err = document.getElementById('error');
    err.textContent = `City "${city}" not found. Try: London, Paris, Dubai, Tokyo, NewYork, Sydney, Moscow, Cairo`;
    err.classList.remove('hidden');
    console.warn('City not found:', city);
    return;
  }

  // Populate main card
  document.getElementById('cityName').textContent = data.city;
  document.getElementById('countryName').textContent = `📍 ${data.country}`;
  document.getElementById('temp').textContent = `${data.temp}°`;
  document.getElementById('weatherIcon').textContent = data.icon;
  document.getElementById('desc').textContent = data.desc;
  document.getElementById('feelsLike').textContent = `${data.feels}°C`;
  document.getElementById('humidity').textContent = `${data.humidity}%`;
  document.getElementById('wind').textContent = `${data.wind} km/h`;
  document.getElementById('pressure').textContent = `${data.pressure} hPa`;
  document.getElementById('visibility').textContent = `${data.visibility} km`;
  document.getElementById('uvIndex').textContent = data.uv;

  document.getElementById('weatherCard').classList.remove('hidden');

  // Forecast
  const today = new Date().getDay();
  const forecastEl = document.getElementById('forecast');
  forecastEl.innerHTML = data.forecast.map((t, i) => {
    const dayIdx = (today + i) % 7;
    return `
      <div class="forecast-day">
        <div class="day">${i === 0 ? 'Today' : DAYS[dayIdx]}</div>
        <div class="icon">${getWeatherEmoji(t)}</div>
        <div class="hi">${t}°</div>
        <div class="lo">${t - 4}°</div>
      </div>
    `;
  }).join('');
  forecastEl.classList.remove('hidden');

  console.info(`Weather loaded for ${data.city}: ${data.temp}°C, ${data.desc}`);
}

document.getElementById('cityInput').addEventListener('keydown', e => {
  if (e.key === 'Enter') fetchWeather();
});

document.addEventListener('DOMContentLoaded', () => {
  fetchWeather();
  console.info('✓ Weather Dashboard initialized');
});''',
);

// ════════════════════════════════════════════
//  PROJECT 3: Calculator
// ════════════════════════════════════════════
const sampleCalculator = SampleProject(
  name: 'Scientific Calculator',
  htmlCode: r'''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Scientific Calculator</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <div class="calc">
    <div class="display">
      <div class="expression" id="expression"></div>
      <div class="result" id="result">0</div>
    </div>

    <div class="keypad">
      <!-- Row 1: Scientific -->
      <button class="key sci" onclick="calc('sin(')">sin</button>
      <button class="key sci" onclick="calc('cos(')">cos</button>
      <button class="key sci" onclick="calc('tan(')">tan</button>
      <button class="key sci" onclick="calc('log(')">log</button>
      <button class="key sci" onclick="calc('ln(')">ln</button>

      <!-- Row 2 -->
      <button class="key sci" onclick="calc('sqrt(')">√</button>
      <button class="key sci" onclick="calc('pi')">π</button>
      <button class="key sci" onclick="calc('e')">e</button>
      <button class="key sci" onclick="calc('^')">x²</button>
      <button class="key sci" onclick="calc('(')">(</button>

      <!-- Row 3: Numbers + ops -->
      <button class="key clear" onclick="clearAll()">AC</button>
      <button class="key clear" onclick="backspace()">⌫</button>
      <button class="key op" onclick="calc('%')">%</button>
      <button class="key op" onclick="calc('/')">÷</button>
      <button class="key sci" onclick="calc(')')">)</button>

      <!-- Row 4 -->
      <button class="key" onclick="calc('7')">7</button>
      <button class="key" onclick="calc('8')">8</button>
      <button class="key" onclick="calc('9')">9</button>
      <button class="key op" onclick="calc('*')">×</button>
      <button class="key sci" onclick="calc('!')">n!</button>

      <!-- Row 5 -->
      <button class="key" onclick="calc('4')">4</button>
      <button class="key" onclick="calc('5')">5</button>
      <button class="key" onclick="calc('6')">6</button>
      <button class="key op" onclick="calc('-')">−</button>
      <button class="key sci" onclick="calc('abs(')">|x|</button>

      <!-- Row 6 -->
      <button class="key" onclick="calc('1')">1</button>
      <button class="key" onclick="calc('2')">2</button>
      <button class="key" onclick="calc('3')">3</button>
      <button class="key op" onclick="calc('+')">+</button>
      <button class="key sci" onclick="toggleDeg()">DEG</button>

      <!-- Row 7 -->
      <button class="key zero" onclick="calc('0')">0</button>
      <button class="key" onclick="calc('.')">.</button>
      <button class="key eq" onclick="evaluate()">=</button>
    </div>

    <div class="history" id="history"></div>
  </div>
  <script src="app.js"></script>
</body>
</html>''',

  cssCode: r'''* { margin:0; padding:0; box-sizing:border-box; }

body {
  font-family: 'Inter', system-ui, sans-serif;
  background: #080b14;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-start;
  min-height: 100vh;
  padding: 24px 16px;
  gap: 16px;
}

.calc {
  width: 100%;
  max-width: 380px;
  background: #0d1120;
  border-radius: 24px;
  overflow: hidden;
  border: 1px solid #1e2a42;
  box-shadow: 0 20px 60px rgba(0,0,0,0.5);
}

.display {
  padding: 24px 20px 16px;
  background: linear-gradient(135deg, #080b14, #0d1a2e);
  text-align: right;
  min-height: 120px;
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
}

.expression {
  color: #4a5568;
  font-size: 0.9rem;
  margin-bottom: 8px;
  min-height: 22px;
  word-break: break-all;
  font-family: monospace;
}

.result {
  color: #e2e8f4;
  font-size: 2.8rem;
  font-weight: 300;
  word-break: break-all;
  transition: all 0.15s;
}

.keypad {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 1px;
  background: #1e2a42;
  padding: 1px;
}

.key {
  background: #111827;
  border: none;
  color: #e2e8f4;
  font-size: 1rem;
  padding: 18px 8px;
  cursor: pointer;
  transition: all 0.1s;
  font-family: inherit;
}
.key:active { background: #1c2438; transform: scale(0.95); }
.key.sci { color: #93c5fd; font-size: 0.85rem; background: #0d1120; }
.key.sci:active { background: #161d2e; }
.key.op  { color: #fbbf24; font-weight: 600; }
.key.op:active  { background: rgba(251,191,36,0.1); }
.key.clear { color: #f87171; }
.key.clear:active { background: rgba(248,113,113,0.1); }
.key.eq {
  background: linear-gradient(135deg, #3b82f6, #8b5cf6);
  color: #fff; font-weight: 700; font-size: 1.2rem;
  grid-column: span 2;
}
.key.eq:active { opacity: 0.85; }
.key.zero { grid-column: span 2; }

.history {
  padding: 12px 16px;
  max-height: 120px;
  overflow-y: auto;
  scrollbar-width: thin;
  scrollbar-color: #1e2a42 transparent;
}

.history-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 6px 0;
  border-bottom: 1px solid #111827;
  font-size: 0.85rem;
  color: #4a5568;
  cursor: pointer;
  transition: color 0.1s;
}
.history-item:hover { color: #94a3b8; }
.history-item .expr { flex: 1; }
.history-item .ans { color: #93c5fd; }''',

  jsCode: r'''// Scientific Calculator

let expression = '';
let isDeg = true;
let history = [];
let justEvaluated = false;

const display = document.getElementById('result');
const exprEl  = document.getElementById('expression');
const histEl  = document.getElementById('history');

function calc(val) {
  if (justEvaluated) {
    // Start fresh unless appending an operator
    if (!'+-*/^%'.includes(val) && !val.endsWith('(')) {
      expression = '';
    }
    justEvaluated = false;
  }
  expression += val;
  updateDisplay();
}

function updateDisplay() {
  // Show a prettified version
  const pretty = expression
    .replace(/\*/g, '×')
    .replace(/\//g, '÷')
    .replace(/pi/g, 'π')
    .replace(/sqrt\(/g, '√(')
    .replace(/\^/g, '²');
  exprEl.textContent = pretty;

  // Live evaluation preview
  try {
    const result = safeEval(expression);
    if (!isNaN(result) && isFinite(result) && expression.length > 0) {
      display.textContent = formatNumber(result);
    }
  } catch (e) {
    // Invalid mid-expression, keep showing last valid
  }
}

function evaluate() {
  if (!expression) return;
  try {
    const result = safeEval(expression);
    if (isNaN(result) || !isFinite(result)) throw new Error('Invalid');

    const formatted = formatNumber(result);
    history.unshift({ expr: expression, ans: formatted });
    if (history.length > 10) history.pop();
    renderHistory();

    exprEl.textContent = expression.replace(/\*/g,'×').replace(/\//g,'÷');
    display.textContent = formatted;
    expression = String(result);
    justEvaluated = true;

    console.log(`${exprEl.textContent} = ${formatted}`);
  } catch (err) {
    display.textContent = 'Error';
    display.style.color = '#f87171';
    setTimeout(() => {
      display.style.color = '';
      display.textContent = expression ? expression : '0';
    }, 1000);
    console.error('Calculation error:', err.message);
  }
}

function safeEval(expr) {
  // Replace mathematical functions
  let e = expr
    .replace(/pi/g, Math.PI)
    .replace(/\be\b/g, Math.E)
    .replace(/\^/g, '**')
    .replace(/sqrt\(/g, 'Math.sqrt(')
    .replace(/abs\(/g, 'Math.abs(')
    .replace(/log\(/g, 'Math.log10(')
    .replace(/ln\(/g, 'Math.log(')
    .replace(/sin\(/g, isDeg ? '(x => Math.sin(x * Math.PI/180))(' : 'Math.sin(')
    .replace(/cos\(/g, isDeg ? '(x => Math.cos(x * Math.PI/180))(' : 'Math.cos(')
    .replace(/tan\(/g, isDeg ? '(x => Math.tan(x * Math.PI/180))(' : 'Math.tan(');

  // Factorial
  e = e.replace(/(\d+)!/g, (_, n) => factorial(parseInt(n)));

  // Validate — only allow safe chars
  if (/[^0-9+\-*/%.()Math\sPIsqrableogn,]/.test(e.replace(/Math\.\w+/g,'').replace(/\s/g,''))) {
    throw new Error('Unsafe expression');
  }

  return Function('"use strict"; return (' + e + ')')();
}

function factorial(n) {
  if (n < 0) throw new Error('Negative factorial');
  if (n === 0 || n === 1) return 1;
  if (n > 20) throw new Error('Too large for factorial');
  let result = 1;
  for (let i = 2; i <= n; i++) result *= i;
  return result;
}

function formatNumber(n) {
  if (Math.abs(n) > 1e12 || (Math.abs(n) < 1e-6 && n !== 0)) {
    return n.toExponential(6);
  }
  const str = String(parseFloat(n.toFixed(10)));
  return str;
}

function clearAll() {
  expression = '';
  justEvaluated = false;
  display.textContent = '0';
  exprEl.textContent = '';
}

function backspace() {
  if (justEvaluated) { clearAll(); return; }
  expression = expression.slice(0, -1);
  if (!expression) display.textContent = '0';
  updateDisplay();
}

function toggleDeg() {
  isDeg = !isDeg;
  document.querySelector('.key[onclick="toggleDeg()"]').textContent = isDeg ? 'DEG' : 'RAD';
  console.info('Mode:', isDeg ? 'Degrees' : 'Radians');
}

function renderHistory() {
  if (history.length === 0) { histEl.innerHTML = ''; return; }
  histEl.innerHTML = history.map(h => `
    <div class="history-item" onclick="useHistory('${h.ans}')">
      <span class="expr">${h.expr.replace(/\*/g,'×').replace(/\//g,'÷')}</span>
      <span class="ans">= ${h.ans}</span>
    </div>
  `).join('');
}

function useHistory(val) {
  expression = val;
  justEvaluated = true;
  display.textContent = val;
  exprEl.textContent = '';
}

// Keyboard support
document.addEventListener('keydown', e => {
  const map = {
    '0':'0','1':'1','2':'2','3':'3','4':'4','5':'5','6':'6','7':'7','8':'8','9':'9',
    '+':'+','-':'-','*':'*','/':'/','.':'.','%':'%','(':')',')':(')'),
    'Enter': null, 'Backspace': null, 'Escape': null
  };
  if (e.key === 'Enter') { evaluate(); return; }
  if (e.key === 'Backspace') { backspace(); return; }
  if (e.key === 'Escape') { clearAll(); return; }
  if (map[e.key] !== undefined) { calc(e.key); return; }
});

document.addEventListener('DOMContentLoaded', () => {
  console.info('✓ Scientific Calculator ready');
  console.info('Keyboard: 0-9, +, -, *, /, Enter, Backspace, Escape');
});''',
);

// ════════════════════════════════════════════
//  PROJECT 4: Kanban Board
// ════════════════════════════════════════════
const sampleKanban = SampleProject(
  name: 'Kanban Board',
  htmlCode: r'''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Kanban Board</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <header>
    <div class="logo">✦ Kanban</div>
    <button class="add-card-btn" onclick="openModal()">+ Add Card</button>
  </header>

  <div class="board" id="board">
    <div class="column" data-col="todo">
      <div class="col-header">
        <span class="col-title">To Do</span>
        <span class="col-count" id="count-todo">0</span>
      </div>
      <div class="cards" id="cards-todo" ondragover="allowDrop(event)" ondrop="drop(event,'todo')"></div>
    </div>
    <div class="column" data-col="inprogress">
      <div class="col-header">
        <span class="col-title">In Progress</span>
        <span class="col-count" id="count-inprogress">0</span>
      </div>
      <div class="cards" id="cards-inprogress" ondragover="allowDrop(event)" ondrop="drop(event,'inprogress')"></div>
    </div>
    <div class="column" data-col="review">
      <div class="col-header">
        <span class="col-title">Review</span>
        <span class="col-count" id="count-review">0</span>
      </div>
      <div class="cards" id="cards-review" ondragover="allowDrop(event)" ondrop="drop(event,'review')"></div>
    </div>
    <div class="column" data-col="done">
      <div class="col-header">
        <span class="col-title">Done</span>
        <span class="col-count" id="count-done">0</span>
      </div>
      <div class="cards" id="cards-done" ondragover="allowDrop(event)" ondrop="drop(event,'done')"></div>
    </div>
  </div>

  <div class="modal-overlay hidden" id="modalOverlay" onclick="closeModalOutside(event)">
    <div class="modal">
      <h2>Add Card</h2>
      <input type="text" id="cardTitle" placeholder="Card title..." autocomplete="off">
      <textarea id="cardDesc" placeholder="Description (optional)..." rows="3"></textarea>
      <div class="modal-row">
        <select id="cardCol">
          <option value="todo">To Do</option>
          <option value="inprogress">In Progress</option>
          <option value="review">Review</option>
          <option value="done">Done</option>
        </select>
        <select id="cardPriority">
          <option value="low">Low Priority</option>
          <option value="medium">Medium Priority</option>
          <option value="high">High Priority</option>
        </select>
      </div>
      <div class="modal-actions">
        <button class="btn-cancel" onclick="closeModal()">Cancel</button>
        <button class="btn-add" onclick="addCard()">Add Card</button>
      </div>
    </div>
  </div>

  <script src="app.js"></script>
</body>
</html>''',

  cssCode: r'''* { margin:0; padding:0; box-sizing:border-box; }
body { font-family:'Inter',system-ui,sans-serif; background:#080b14; color:#e2e8f4; min-height:100vh; }

header {
  padding:16px 24px; background:#0d1120; border-bottom:1px solid #1e2a42;
  display:flex; align-items:center; justify-content:space-between;
}
.logo { font-size:1.2rem; font-weight:800; background:linear-gradient(135deg,#3b82f6,#8b5cf6); -webkit-background-clip:text; -webkit-text-fill-color:transparent; background-clip:text; }

.add-card-btn {
  background:#3b82f6; color:#fff; border:none; border-radius:8px;
  padding:8px 16px; font-size:0.85rem; font-weight:600; cursor:pointer; transition:all .15s;
}
.add-card-btn:hover { background:#2563eb; }

.board {
  display:grid; grid-template-columns:repeat(4,1fr); gap:16px;
  padding:24px; height:calc(100vh - 56px); overflow-x:auto;
}

.column {
  background:#0d1120; border-radius:16px; border:1px solid #1e2a42;
  display:flex; flex-direction:column; min-height:200px;
}
.col-header {
  padding:14px 16px; display:flex; align-items:center; justify-content:space-between;
  border-bottom:1px solid #1e2a42; flex-shrink:0;
}
.col-title { font-size:0.85rem; font-weight:600; text-transform:uppercase; letter-spacing:.08em; color:#94a3b8; }
.col-count {
  background:#1e2a42; color:#94a3b8; border-radius:10px;
  padding:2px 8px; font-size:0.75rem; font-weight:700;
}

.cards { flex:1; padding:12px; display:flex; flex-direction:column; gap:8px; overflow-y:auto; }
.cards.drag-over { background:rgba(59,130,246,0.05); border-radius:8px; }

.card {
  background:#111827; border:1px solid #1e2a42; border-radius:12px;
  padding:14px; cursor:grab; transition:all .15s;
  animation:fadeIn .2s ease;
}
.card:hover { border-color:#243050; transform:translateY(-1px); box-shadow:0 4px 16px rgba(0,0,0,0.3); }
.card:active { cursor:grabbing; }
.card.dragging { opacity:0.4; transform:rotate(2deg); }

@keyframes fadeIn { from{opacity:0;transform:translateY(4px)} to{opacity:1;transform:translateY(0)} }

.card-header { display:flex; align-items:flex-start; justify-content:space-between; gap:8px; margin-bottom:8px; }
.card-title { font-size:0.9rem; font-weight:600; line-height:1.4; }
.card-priority { flex-shrink:0; }
.priority-badge {
  font-size:0.65rem; font-weight:700; text-transform:uppercase; letter-spacing:.05em;
  padding:2px 6px; border-radius:4px;
}
.priority-badge.high   { background:rgba(248,113,113,.15); color:#f87171; }
.priority-badge.medium { background:rgba(251,191,36,.15);  color:#fbbf24; }
.priority-badge.low    { background:rgba(34,211,160,.15);  color:#22d3a0; }

.card-desc { font-size:0.8rem; color:#4a5568; margin-bottom:10px; line-height:1.5; }

.card-footer { display:flex; align-items:center; justify-content:space-between; }
.card-date { font-size:0.7rem; color:#2d3748; }
.card-actions { display:flex; gap:4px; }
.card-btn {
  width:24px; height:24px; border:none; background:transparent;
  color:#4a5568; cursor:pointer; border-radius:4px; font-size:0.75rem;
  display:flex; align-items:center; justify-content:center; transition:all .1s;
}
.card-btn:hover { background:#1e2a42; color:#e2e8f4; }

/* Modal */
.modal-overlay {
  position:fixed; inset:0; background:rgba(0,0,0,0.7);
  display:flex; align-items:center; justify-content:center; z-index:1000;
  backdrop-filter:blur(4px);
}
.modal-overlay.hidden { display:none; }
.modal {
  background:#111827; border:1px solid #1e2a42; border-radius:20px;
  padding:28px; width:min(420px,90vw); display:flex; flex-direction:column; gap:14px;
}
.modal h2 { font-size:1.1rem; font-weight:700; }
.modal input, .modal textarea, .modal select {
  background:#0d1120; border:1px solid #1e2a42; border-radius:10px;
  padding:12px 14px; color:#e2e8f4; font-size:0.9rem; outline:none;
  font-family:inherit; transition:border-color .2s; width:100%;
}
.modal input:focus, .modal textarea:focus { border-color:#3b82f6; }
.modal textarea { resize:vertical; }
.modal-row { display:grid; grid-template-columns:1fr 1fr; gap:10px; }
.modal-actions { display:flex; gap:10px; justify-content:flex-end; }
.btn-cancel { background:transparent; border:1px solid #1e2a42; color:#94a3b8; border-radius:8px; padding:10px 18px; cursor:pointer; }
.btn-add { background:#3b82f6; color:#fff; border:none; border-radius:8px; padding:10px 18px; cursor:pointer; font-weight:600; }

@media(max-width:768px) {
  .board { grid-template-columns:280px 280px 280px 280px; }
}''',

  jsCode: r'''// Kanban Board

let cards = JSON.parse(localStorage.getItem('dp_kanban') || '[]');
let nextId = Date.now();
let draggedId = null;

// Sample data on first load
if (cards.length === 0) {
  cards = [
    { id: 1, title: 'Design system tokens', desc: 'Create color palette and typography scale', col: 'done', priority: 'high', date: '2024-01-10' },
    { id: 2, title: 'Build API layer', desc: 'REST endpoints for user management', col: 'inprogress', priority: 'high', date: '2024-01-12' },
    { id: 3, title: 'Write unit tests', desc: 'Coverage for core business logic', col: 'todo', priority: 'medium', date: '2024-01-15' },
    { id: 4, title: 'Setup CI/CD pipeline', desc: 'GitHub Actions for automated deployment', col: 'review', priority: 'medium', date: '2024-01-11' },
    { id: 5, title: 'Mobile responsive layout', desc: '', col: 'inprogress', priority: 'low', date: '2024-01-13' },
    { id: 6, title: 'Performance audit', desc: 'Lighthouse score > 90', col: 'todo', priority: 'low', date: '2024-01-16' },
  ];
  saveCards();
}

function saveCards() {
  localStorage.setItem('dp_kanban', JSON.stringify(cards));
}

function addCard() {
  const title = document.getElementById('cardTitle').value.trim();
  if (!title) {
    document.getElementById('cardTitle').style.borderColor = '#f87171';
    return;
  }
  cards.push({
    id: nextId++,
    title,
    desc: document.getElementById('cardDesc').value.trim(),
    col: document.getElementById('cardCol').value,
    priority: document.getElementById('cardPriority').value,
    date: new Date().toISOString().slice(0, 10),
  });
  saveCards();
  closeModal();
  render();
  console.info('Card added:', title);
}

function deleteCard(id) {
  cards = cards.filter(c => c.id !== id);
  saveCards();
  render();
}

function moveCard(id, col) {
  const card = cards.find(c => c.id === id);
  if (card) { card.col = col; saveCards(); render(); }
}

function render() {
  const cols = ['todo', 'inprogress', 'review', 'done'];
  cols.forEach(col => {
    const colCards = cards.filter(c => c.col === col);
    const el = document.getElementById(`cards-${col}`);
    const count = document.getElementById(`count-${col}`);
    count.textContent = colCards.length;

    el.innerHTML = colCards.map(card => `
      <div class="card" id="card-${card.id}"
        draggable="true"
        ondragstart="dragStart(event,${card.id})"
        ondragend="dragEnd(event)">
        <div class="card-header">
          <div class="card-title">${escHtml(card.title)}</div>
          <div class="card-priority">
            <span class="priority-badge ${card.priority}">${card.priority}</span>
          </div>
        </div>
        ${card.desc ? `<div class="card-desc">${escHtml(card.desc)}</div>` : ''}
        <div class="card-footer">
          <span class="card-date">${card.date}</span>
          <div class="card-actions">
            <button class="card-btn" onclick="deleteCard(${card.id})" title="Delete">✕</button>
          </div>
        </div>
      </div>
    `).join('');
  });
  console.log('Board: todo=%d, inprogress=%d, review=%d, done=%d',
    ...cols.map(c => cards.filter(x => x.col === c).length));
}

function escHtml(str) {
  return str.replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'})[c]);
}

// Drag & Drop
function dragStart(e, id) {
  draggedId = id;
  setTimeout(() => document.getElementById(`card-${id}`)?.classList.add('dragging'), 0);
  e.dataTransfer.effectAllowed = 'move';
}
function dragEnd(e) {
  document.querySelectorAll('.card').forEach(c => c.classList.remove('dragging'));
  draggedId = null;
}
function allowDrop(e) {
  e.preventDefault();
  e.currentTarget.classList.add('drag-over');
}
function drop(e, col) {
  e.preventDefault();
  e.currentTarget.classList.remove('drag-over');
  if (draggedId) { moveCard(draggedId, col); }
}

// Remove drag-over class when leaving
document.querySelectorAll && document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('.cards').forEach(el => {
    el.addEventListener('dragleave', () => el.classList.remove('drag-over'));
  });
});

// Modal
function openModal() { document.getElementById('modalOverlay').classList.remove('hidden'); document.getElementById('cardTitle').focus(); }
function closeModal() {
  document.getElementById('modalOverlay').classList.add('hidden');
  document.getElementById('cardTitle').value = '';
  document.getElementById('cardDesc').value = '';
  document.getElementById('cardTitle').style.borderColor = '';
}
function closeModalOutside(e) { if (e.target === document.getElementById('modalOverlay')) closeModal(); }

document.addEventListener('keydown', e => {
  if (e.key === 'Escape') closeModal();
  if ((e.ctrlKey||e.metaKey) && e.key === 'n') { e.preventDefault(); openModal(); }
});

document.addEventListener('DOMContentLoaded', () => {
  render();
  console.info('✓ Kanban Board initialized —', cards.length, 'cards');
  console.info('Drag cards between columns, Ctrl+N to add card');
});''',
);

const List<SampleProject> allSamples = [
  sampleTodoApp,
  sampleWeatherApp,
  sampleCalculator,
  sampleKanban,
];
