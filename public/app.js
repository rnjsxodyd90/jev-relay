import { prepareVoice, openMicrophone, transcribeAudio, decodeAudioFile } from './voice.js';

const TASK_LABELS = {
  decision_bundle: 'Decision bundle',
  memory_selection: 'Memory selection',
  word_sense: 'Word sense'
};
const DECISION_LABELS = {
  action: 'Action',
  memory: 'Memory',
  register: 'Register',
  sense: 'Sense'
};
const DECISION_ORDER = ['action', 'memory', 'register', 'sense'];

const workbenchView = document.querySelector('#workbench-view');
const evidenceView = document.querySelector('#evidence-view');
const integrationView = document.querySelector('#integration-view');
const viewTitle = document.querySelector('#view-title');
const viewContext = document.querySelector('#view-context');
const datasetStamp = document.querySelector('#dataset-stamp');
const appStatus = document.querySelector('#app-status');
const navButtons = [...document.querySelectorAll('[data-view]')];

let evidence = null;
let liveStatus = null;
let activeView = 'workbench';
let activeMode = 'replay';
let activeTask = 'decision_bundle';
let activeCaseId = 'bundle_m1';
let activeRound = 1;
let ledgerTask = 'all';
let ledgerRound = 'all';
let liveText = '';
let liveContext = '';
let liveResult = null;
let liveError = '';
let livePending = false;
let liveRequestSerial = 0;
let activeLiveRequest = 0;
let liveRunButton = null;
let liveSourceTextarea = null;
let voiceReady = false;
let voicePreparing = false;
let voiceBusy = false;
let microphoneOpening = false;
let voiceOperationSerial = 0;
let activeVoiceOperation = 0;
let voiceMessage = 'Voice is optional. Prepare the local model before recording or choosing a file.';
let recorder = null;
let recorderToken = 0;
let recordingStartedAt = 0;
let recordingButton = null;
let voicePrepareButton = null;
let voiceFileInput = null;
let voiceFileLabel = null;
let voiceStatusElement = null;
let levelFill = null;
let localDutchVoice = null;

function element(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined && text !== null) node.textContent = String(text);
  return node;
}

function announce(message) {
  appStatus.textContent = '';
  window.requestAnimationFrame(() => { appStatus.textContent = message; });
}

function beginVoiceOperation() {
  const token = ++voiceOperationSerial;
  activeVoiceOperation = token;
  return token;
}

function invalidateVoiceOperations() {
  activeVoiceOperation = ++voiceOperationSerial;
}

function voiceOperationIsCurrent(token) {
  return token === activeVoiceOperation && activeMode === 'live' && activeView === 'workbench';
}

function voiceIsOccupied() {
  return voiceBusy || microphoneOpening || Boolean(recorder);
}

function updateLiveRunButton() {
  if (!liveRunButton) return;
  liveRunButton.textContent = livePending ? 'Running interpretation' : 'Run interpretation';
  liveRunButton.disabled = livePending || voiceIsOccupied() || !isLiveReady() || !liveText.trim();
}

function updateVoiceControls() {
  if (voicePrepareButton) {
    voicePrepareButton.textContent = voicePreparing ? 'Preparing local voice' : voiceReady ? 'Local voice ready' : 'Prepare local voice';
    voicePrepareButton.disabled = voiceReady || voicePreparing || voiceIsOccupied();
  }
  if (recordingButton) {
    recordingButton.textContent = recorder ? 'Stop recording' : microphoneOpening ? 'Opening microphone' : voiceBusy ? 'Local transcription in progress' : 'Start recording';
    recordingButton.disabled = recorder ? false : !voiceReady || voicePreparing || voiceBusy || microphoneOpening;
    recordingButton.setAttribute('aria-pressed', String(Boolean(recorder)));
  }
  const fileDisabled = !voiceReady || voicePreparing || voiceBusy || microphoneOpening || Boolean(recorder);
  if (voiceFileInput) voiceFileInput.disabled = fileDisabled;
  if (voiceFileLabel) voiceFileLabel.classList.toggle('is-disabled', fileDisabled);
  if (voiceStatusElement) voiceStatusElement.textContent = voiceMessage;
  updateLiveRunButton();
}

function invalidateLiveTurn(updateDom = true) {
  activeLiveRequest = ++liveRequestSerial;
  liveResult = null;
  liveError = '';
  window.speechSynthesis?.cancel();
  if (updateDom && activeMode === 'live' && activeView === 'workbench') {
    workbenchView.querySelector('.live-result')?.remove();
    workbenchView.querySelector('.error-box')?.remove();
    const pane = workbenchView.querySelector('.decision-pane');
    if (pane) pane.replaceWith(decisionRail(null, null, 'Decision rail'));
  }
  updateLiveRunButton();
}

function formatTask(task) {
  return TASK_LABELS[task] || task.replaceAll('_', ' ');
}

function formatPercent(value, total) {
  if (!total) return '0%';
  const percentage = value / total * 100;
  return `${Number.isInteger(percentage) ? percentage : percentage.toFixed(1)}%`;
}

function formatDate(value) {
  if (!value) return 'Recorded evidence';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return 'Recorded evidence';
  return `Recorded ${new Intl.DateTimeFormat('en', { dateStyle: 'medium' }).format(date)}`;
}

function setSelectOptions(select, options, selected) {
  for (const optionData of options) {
    const option = document.createElement('option');
    option.value = String(optionData.value);
    option.textContent = optionData.label;
    option.selected = String(optionData.value) === String(selected);
    select.append(option);
  }
}

function createField(labelText, control, grow = false) {
  const field = element('div', grow ? 'field grow' : 'field');
  const id = control.id || `field-${Math.random().toString(36).slice(2)}`;
  control.id = id;
  const label = element('label', '', labelText);
  label.htmlFor = id;
  field.append(label, control);
  return field;
}

function badge(text, tone = 'neutral') {
  return element('span', `badge ${tone}`, text);
}

function selectedCase() {
  return evidence.cases.find(item => item.id === activeCaseId) || evidence.cases[0];
}

function caseResult(id, provider, round) {
  return evidence.results.find(row => row.id === id && row.provider === provider && Number(row.round) === Number(round));
}

function filteredCases(task = activeTask) {
  if (task === 'all') return evidence.cases;
  return evidence.cases.filter(item => item.task === task);
}

function modeButton(label, mode) {
  const button = element('button', '', label);
  button.type = 'button';
  button.setAttribute('aria-pressed', String(activeMode === mode));
  button.addEventListener('click', async () => {
    if (activeMode === mode) return;
    invalidateVoiceOperations();
    invalidateLiveTurn(false);
    await stopActiveRecording(true);
    activeMode = mode;
    const current = selectedCase();
    if (mode === 'live') {
      liveText = current.state.source || '';
      liveContext = current.state.context || '';
    }
    renderWorkbench();
    announce(mode === 'live' ? 'Live mode selected. Review the service disclosure before sending.' : 'Recorded replay selected.');
  });
  return button;
}

function renderReplayControls(container) {
  const strip = element('div', 'control-strip');
  const row = element('div', 'control-row');

  const taskSelect = document.createElement('select');
  setSelectOptions(taskSelect, [
    { value: 'decision_bundle', label: 'Decision bundle, 12 cases' },
    { value: 'memory_selection', label: 'Memory selection, 12 cases' },
    { value: 'word_sense', label: 'Word sense, 12 cases' },
    { value: 'all', label: 'All benchmark tasks, 36 cases' }
  ], activeTask);
  taskSelect.addEventListener('change', () => {
    activeTask = taskSelect.value;
    const available = filteredCases();
    if (!available.some(item => item.id === activeCaseId)) activeCaseId = available[0].id;
    renderWorkbench();
    announce(`${formatTask(activeTask)} cases loaded.`);
  });

  const caseSelect = document.createElement('select');
  setSelectOptions(caseSelect, filteredCases().map(item => ({
    value: item.id,
    label: `${item.id}: ${item.state.source}`
  })), activeCaseId);
  caseSelect.addEventListener('change', () => {
    activeCaseId = caseSelect.value;
    renderWorkbench();
    announce(`Recorded case ${activeCaseId} selected.`);
  });

  const roundSelect = document.createElement('select');
  setSelectOptions(roundSelect, [1, 2, 3].map(round => ({ value: round, label: `Repetition ${round}` })), activeRound);
  roundSelect.addEventListener('change', () => {
    activeRound = Number(roundSelect.value);
    renderWorkbench();
    announce(`Repetition ${activeRound} selected.`);
  });

  row.append(
    createField('Task', taskSelect),
    createField('Recorded case', caseSelect, true),
    createField('Run', roundSelect)
  );
  strip.append(row);
  container.append(strip);
}

function renderVoiceBox(container) {
  const box = element('div', 'voice-box');
  const row = element('div', 'voice-row');
  const controls = element('div', 'voice-controls');

  const prepare = element('button', 'secondary');
  prepare.type = 'button';
  prepare.addEventListener('click', startVoicePreparation);
  voicePrepareButton = prepare;

  const record = element('button', 'secondary');
  record.type = 'button';
  record.addEventListener('click', async () => {
    if (recorder) await finishRecording(false);
    else await startRecording();
  });
  recordingButton = record;

  const fileLabel = element('label', 'file-button', 'Choose audio file');
  const fileInput = document.createElement('input');
  fileInput.type = 'file';
  fileInput.accept = 'audio/*';
  fileInput.setAttribute('aria-label', 'Choose an audio file to transcribe locally');
  fileInput.addEventListener('change', async () => {
    const [file] = fileInput.files;
    if (!file || voiceIsOccupied()) return;
    const token = beginVoiceOperation();
    invalidateLiveTurn();
    voiceBusy = true;
    voiceMessage = 'Decoding and transcribing on this device.';
    updateVoiceControls();
    try {
      const audio = await decodeAudioFile(file);
      if (!voiceOperationIsCurrent(token)) return;
      const result = await transcribeAudio(audio, 'en');
      if (!voiceOperationIsCurrent(token)) return;
      liveText = result.text || '';
      if (liveSourceTextarea) liveSourceTextarea.value = liveText;
      voiceMessage = result.text ? `Local transcript ready in ${result.ms} ms. Review it before sending.` : 'No speech was found in that audio file.';
      announce(voiceMessage);
    } catch (error) {
      if (!voiceOperationIsCurrent(token)) return;
      voiceMessage = error.message || 'The audio file could not be transcribed.';
      announce(voiceMessage);
    } finally {
      voiceBusy = false;
      if (!voiceOperationIsCurrent(token)) voiceMessage = 'The earlier local transcription was not applied because the turn changed.';
      fileInput.value = '';
      updateVoiceControls();
    }
  });
  fileLabel.append(fileInput);
  voiceFileInput = fileInput;
  voiceFileLabel = fileLabel;

  const meter = element('div', 'level-meter');
  meter.setAttribute('aria-hidden', 'true');
  levelFill = element('span');
  meter.append(levelFill);

  controls.append(prepare, record, fileLabel);
  row.append(controls, meter);
  const status = element('p', 'voice-status', voiceMessage);
  status.setAttribute('role', 'status');
  voiceStatusElement = status;
  box.append(row, status);
  container.append(box);
  updateVoiceControls();
}

async function startVoicePreparation() {
  if (voiceReady || voicePreparing || voiceIsOccupied()) return;
  voicePreparing = true;
  voiceMessage = 'Starting the local speech model download.';
  updateVoiceControls();
  try {
    await prepareVoice(message => {
      voiceMessage = message;
      if (voiceStatusElement) voiceStatusElement.textContent = message;
      announce(message);
    });
    voiceReady = true;
    voiceMessage = 'Local speech is ready. Audio stays on this device.';
  } catch (error) {
    voiceMessage = error.message || 'The local speech model could not be prepared.';
  } finally {
    voicePreparing = false;
    updateVoiceControls();
    announce(voiceMessage);
  }
}

async function startRecording() {
  if (!voiceReady || voiceIsOccupied()) return;
  const token = beginVoiceOperation();
  invalidateLiveTurn();
  microphoneOpening = true;
  voiceMessage = 'Waiting for microphone permission.';
  updateVoiceControls();
  try {
    const acquired = await openMicrophone((level, seconds) => {
      if (!voiceOperationIsCurrent(token)) return;
      if (levelFill) levelFill.style.width = `${Math.min(100, Math.round(level * 500))}%`;
      if (seconds > 0 && recordingButton) recordingButton.setAttribute('aria-label', `Stop recording, ${Math.round(seconds)} seconds captured`);
    }, () => {
      if (voiceOperationIsCurrent(token)) finishRecording(false, true);
    });
    if (!voiceOperationIsCurrent(token)) {
      await acquired.stop(true);
      return;
    }
    recorder = acquired;
    recorderToken = token;
    recordingStartedAt = Date.now();
    voiceMessage = 'Listening locally. Stop when the utterance is complete.';
    announce('Recording started. Audio stays on this device.');
  } catch (error) {
    if (!voiceOperationIsCurrent(token)) return;
    voiceMessage = error.message || 'The microphone could not start.';
    announce(voiceMessage);
  } finally {
    microphoneOpening = false;
    if (!voiceOperationIsCurrent(token)) voiceMessage = 'The microphone request was discarded because the turn changed.';
    updateVoiceControls();
  }
}

async function finishRecording(discard = false, reachedLimit = false) {
  const active = recorder;
  const token = recorderToken;
  if (!active) return;
  recorder = null;
  recorderToken = 0;
  voiceBusy = !discard;
  voiceMessage = discard ? 'Stopping local recording.' : reachedLimit ? 'Thirty-second limit reached. Transcribing locally.' : 'Transcribing locally.';
  updateVoiceControls();
  try {
    const audio = await active.stop(discard);
    if (discard || !audio) {
      if (voiceOperationIsCurrent(token)) voiceMessage = 'Recording stopped. No audio was retained.';
      return;
    }
    if (!voiceOperationIsCurrent(token)) return;
    const result = await transcribeAudio(audio, 'en');
    if (!voiceOperationIsCurrent(token)) return;
    liveText = result.text || '';
    if (liveSourceTextarea) liveSourceTextarea.value = liveText;
    const duration = Math.max(1, Math.round((Date.now() - recordingStartedAt) / 1000));
    voiceMessage = result.text ? `Local transcript ready from ${duration} seconds of audio. Review it before sending.` : 'No speech was found in the recording.';
    announce(voiceMessage);
  } catch (error) {
    if (!voiceOperationIsCurrent(token)) return;
    voiceMessage = error.message || 'The recording could not be transcribed.';
    announce(voiceMessage);
  } finally {
    voiceBusy = false;
    if (!voiceOperationIsCurrent(token)) voiceMessage = 'The earlier local transcription was not applied because the turn changed.';
    updateVoiceControls();
  }
}

async function stopActiveRecording(discard = true) {
  if (recorder) await finishRecording(discard);
}

function decisionRail(decisions, answers, title = 'Jev decisions') {
  const pane = element('aside', 'decision-pane');
  pane.append(element('h2', '', title));
  pane.append(element('p', '', 'One batch call returns the four routing decisions together.'));
  const rail = element('div', 'decision-rail');

  for (const key of DECISION_ORDER) {
    const step = element('div', 'decision-step');
    step.append(element('span', 'decision-node'));
    step.append(element('p', 'decision-name', DECISION_LABELS[key]));
    const choice = decisions?.[key]?.choice ?? decisions?.[key] ?? 'Not run';
    step.append(element('p', 'decision-choice', choice));
    const confidence = decisions?.[key]?.confidence ?? answers?.[key]?.confidence;
    if (Number.isFinite(confidence)) {
      const track = element('div', 'confidence-track');
      const fill = element('span');
      fill.style.width = `${Math.max(0, Math.min(100, confidence * 100))}%`;
      track.append(fill);
      step.append(track, element('div', 'confidence-label', `${Math.round(confidence * 100)}% confidence`));
    }
    rail.append(step);
  }
  pane.append(rail);
  return pane;
}

function providerResult(provider, result) {
  const block = element('article', 'provider-result');
  const title = element('div', 'provider-title');
  title.append(element('h3', '', provider === 'jev' ? 'Jev' : 'Qwen'));
  title.append(element('span', 'latency', result ? `${result.elapsedMs} ms` : 'No row'));
  block.append(title);
  if (!result) return block;
  block.append(badge(result.correct ? 'Exact match' : 'Mismatch', result.correct ? 'good' : 'bad'));
  const list = element('dl', 'choice-list');
  for (const [key, value] of Object.entries(result.choices || {})) {
    const item = element('div');
    item.append(element('dt', '', DECISION_LABELS[key] || key), element('dd', '', value));
    list.append(item);
  }
  block.append(list);
  return block;
}

function replayComparison(caseData, jev, qwen) {
  const comparison = element('section', 'comparison');
  const head = element('div', 'comparison-head');
  head.append(element('h2', '', 'Recorded provider comparison'));
  head.append(element('p', '', `Measured repetition ${activeRound}. These are stored benchmark responses, not a live inference.`));
  const grid = element('div', 'provider-grid');
  grid.append(providerResult('jev', jev), providerResult('qwen', qwen));
  const note = element('p', 'evidence-note', 'This replay records decisions and latency only. It does not contain a generated Dutch translation.');
  comparison.append(head, grid, note);
  return comparison;
}

function renderLiveSetup(container) {
  const ready = isLiveReady();
  const panel = element('div', ready ? 'notice' : 'live-setup');
  if (ready) {
    const remaining = liveStatus.remainingCalls === null || liveStatus.remainingCalls === undefined ? 'not reported' : liveStatus.remainingCalls;
    panel.append(element('p', '', `Live calls are enabled for ${liveStatus.model || 'the configured Jev model'}. Server-reported call allowance: ${remaining}.`));
  } else {
    const paragraph = element('p');
    paragraph.append(document.createTextNode('Live mode is not ready. '));
    if (liveStatus?.unavailableReason) {
      paragraph.append(document.createTextNode('The browser could not read GET /api/status. Start the application server and reload this page.'));
    } else {
      const missing = [];
      if (!liveStatus?.liveEnabled) missing.push('enable the live route');
      if (!liveStatus?.jevConfigured) missing.push('configure TYPESAFE_API_KEY');
      if (!liveStatus?.qwenConfigured) missing.push('configure NEBIUS_API_KEY');
      if (liveStatus?.remainingCalls !== undefined && liveStatus?.remainingCalls !== null && liveStatus.remainingCalls <= 0) missing.push('restore the server call allowance');
      paragraph.append(document.createTextNode(`Complete the server setup: ${missing.join(', ')}. Then reload this page. No successful result is simulated here.`));
    }
    panel.append(paragraph);
  }
  container.append(panel);
}

function isLiveReady() {
  return Boolean(liveStatus?.liveEnabled && liveStatus?.jevConfigured && liveStatus?.qwenConfigured && (liveStatus.remainingCalls === undefined || liveStatus.remainingCalls === null || liveStatus.remainingCalls > 0));
}

function createEditor(caseData, isLive) {
  const pane = element('section', 'editor-pane');
  const heading = element('div', 'editor-heading');
  const headingCopy = element('div');
  headingCopy.append(element('h2', '', isLive ? 'Live utterance' : 'Recorded utterance'));
  headingCopy.append(element('p', '', isLive ? 'Edit the transcript and context before executing.' : `${formatTask(caseData.task)}, repetition ${activeRound}`));
  heading.append(headingCopy, element('span', 'case-code', isLive ? 'en → nl' : caseData.id));
  pane.append(heading);

  const fields = element('div', 'editor-fields');
  const source = document.createElement('textarea');
  source.className = 'source-text';
  source.rows = 4;
  source.value = isLive ? liveText : caseData.state.source;
  source.readOnly = !isLive;
  source.addEventListener('input', () => {
    liveText = source.value;
    if (voiceIsOccupied()) invalidateVoiceOperations();
    invalidateLiveTurn();
  });
  if (isLive) liveSourceTextarea = source;

  const context = document.createElement('textarea');
  context.className = 'context-text';
  context.rows = 3;
  context.value = isLive ? liveContext : caseData.state.context;
  context.readOnly = !isLive;
  context.addEventListener('input', () => {
    liveContext = context.value;
    invalidateLiveTurn();
  });

  fields.append(createField('English source', source), createField('Interpretive context', context));
  pane.append(fields);

  if (!isLive) {
    pane.append(element('p', 'editor-note', 'Recorded fields are read-only so the displayed decisions remain tied to the measured case.'));
  } else {
    renderVoiceBox(pane);
    const executeRow = element('div', 'execute-row');
    executeRow.append(element('p', 'execute-hint', 'Only text and context are sent. Voice audio is processed locally and is not uploaded.'));
    const execute = element('button', 'primary', livePending ? 'Running interpretation' : 'Run interpretation');
    execute.type = 'button';
    execute.addEventListener('click', runLiveInterpretation);
    liveRunButton = execute;
    updateLiveRunButton();
    executeRow.append(execute);
    pane.append(executeRow);
  }
  return pane;
}

async function runLiveInterpretation() {
  if (!isLiveReady() || livePending || voiceIsOccupied() || !liveText.trim()) return;
  invalidateVoiceOperations();
  await stopActiveRecording(true);
  if (activeMode !== 'live' || activeView !== 'workbench') return;
  const requestToken = ++liveRequestSerial;
  activeLiveRequest = requestToken;
  livePending = true;
  liveError = '';
  liveResult = null;
  renderWorkbench();
  announce('Running a live interpretation request.');
  const controller = new AbortController();
  const timeout = window.setTimeout(() => controller.abort(), 45000);
  try {
    const response = await fetch('/api/interpret', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text: liveText.trim(), context: liveContext.trim(), source: 'en', target: 'nl', senseOptions: {} }),
      signal: controller.signal
    });
    let payload;
    try { payload = await response.json(); }
    catch { payload = { error: `The server returned ${response.status} without a JSON response.`, code: 'INVALID_RESPONSE' }; }
    if (!response.ok || payload.error) {
      const code = payload.code ? ` (${payload.code})` : '';
      throw Error(`${payload.error || `Live request failed with status ${response.status}.`}${code}`);
    }
    if (payload.mode !== 'live') throw Error('The server response was not marked as live. No result was displayed.');
    if (requestToken !== activeLiveRequest) return;
    liveResult = payload;
    announce('Live interpretation complete.');
  } catch (error) {
    if (requestToken !== activeLiveRequest) return;
    liveError = error.name === 'AbortError' ? 'The live request exceeded 45 seconds. Check the server connection and try again.' : (error.message || 'The live request failed.');
    announce(liveError);
  } finally {
    window.clearTimeout(timeout);
    try {
      const statusResponse = await fetch('/api/status', { signal: AbortSignal.timeout(3000) });
      if (statusResponse.ok) liveStatus = await statusResponse.json();
    } catch { /* Preserve the last known status; server-side caps remain authoritative. */ }
    livePending = false;
    if (requestToken === activeLiveRequest && activeMode === 'live' && activeView === 'workbench') renderWorkbench();
    else updateLiveRunButton();
  }
}

function refreshDutchVoice() {
  if (!('speechSynthesis' in window)) {
    localDutchVoice = null;
    return;
  }
  localDutchVoice = window.speechSynthesis.getVoices().find(voice => /^nl(?:-|_)/i.test(voice.lang) && voice.localService === true) || null;
}

function speakDutch(text) {
  refreshDutchVoice();
  if (!text || !localDutchVoice || !('speechSynthesis' in window)) return;
  window.speechSynthesis.cancel();
  const utterance = new SpeechSynthesisUtterance(text);
  utterance.lang = localDutchVoice.lang;
  utterance.voice = localDutchVoice;
  window.speechSynthesis.speak(utterance);
  announce('Playing the Dutch translation with a local Dutch voice.');
}

function renderLiveResult(container) {
  if (liveError) container.append(element('div', 'error-box', liveError));
  if (!liveResult) return;

  const comparison = element('section', 'comparison live-result');
  if (liveResult.translatedText) {
    const translation = element('div', 'translation-block');
    translation.append(element('p', 'context-line', 'Dutch output'));
    translation.append(element('p', 'translation-text', liveResult.translatedText));
    const actions = element('div', 'inline-actions');
    const play = element('button', 'secondary', 'Play Dutch locally');
    play.type = 'button';
    refreshDutchVoice();
    play.disabled = !localDutchVoice;
    play.addEventListener('click', () => speakDutch(liveResult.translatedText));
    actions.append(play);
    actions.append(element('span', 'voice-status', localDutchVoice ? `Voice: ${localDutchVoice.name}` : 'No local Dutch voice is installed, so playback is disabled.'));
    translation.append(actions);
    comparison.append(translation);
  }
  if (liveResult.clarification) {
    const clarification = element('div', 'translation-block');
    clarification.append(element('p', 'context-line', 'Clarification needed'));
    clarification.append(element('p', 'translation-text', liveResult.clarification));
    comparison.append(clarification);
  }

  const grid = element('div', 'provider-grid');
  const route = element('article', 'provider-result');
  route.append(element('h3', '', 'Live route'));
  route.append(element('p', 'translation-text', liveResult.route || 'Not reported'));
  const routeMeta = element('div', 'result-meta');
  if (liveResult.model) routeMeta.append(element('span', '', `Model: ${liveResult.model}`));
  if (typeof liveResult.usedTranslator === 'boolean') routeMeta.append(element('span', '', liveResult.usedTranslator ? 'Nebius translator used' : 'Translator not used'));
  route.append(routeMeta);
  if (liveResult.reason) route.append(element('p', 'editor-note', liveResult.reason));

  const timing = element('article', 'provider-result');
  timing.append(element('h3', '', 'Measured timing'));
  const timings = element('dl', 'choice-list');
  for (const [key, label] of [['decisionMs', 'Decision'], ['translationMs', 'Translation'], ['totalMs', 'Total']]) {
    const item = element('div');
    item.append(element('dt', '', label), element('dd', '', Number.isFinite(liveResult.timing?.[key]) ? `${liveResult.timing[key]} ms` : 'Not reported'));
    timings.append(item);
  }
  timing.append(timings);
  grid.append(route, timing);
  comparison.append(grid);
  container.append(comparison);
}

function renderWorkbench() {
  if (!evidence) return;
  liveRunButton = null;
  liveSourceTextarea = null;
  recordingButton = null;
  voicePrepareButton = null;
  voiceFileInput = null;
  voiceFileLabel = null;
  voiceStatusElement = null;
  levelFill = null;
  workbenchView.replaceChildren();
  const caseData = selectedCase();
  const modeRow = element('div', 'mode-row');
  const segmented = element('div', 'segmented');
  segmented.setAttribute('role', 'group');
  segmented.setAttribute('aria-label', 'Workbench mode');
  segmented.append(modeButton('Recorded replay', 'replay'), modeButton('Live opt-in', 'live'));
  const disclosure = element('p', 'disclosure');
  if (activeMode === 'replay') {
    disclosure.append(element('strong', '', 'Recorded evidence. '), document.createTextNode('No request is running.'));
  } else {
    disclosure.append(element('strong', '', 'Live disclosure. '), document.createTextNode('Text and context go to TypeSafe and, on a translation miss, may go to Nebius. Raw audio never leaves this browser.'));
  }
  modeRow.append(segmented, disclosure);
  workbenchView.append(modeRow);

  if (activeMode === 'replay') renderReplayControls(workbenchView);
  else renderLiveSetup(workbenchView);

  const grid = element('div', 'workbench-grid');
  grid.append(createEditor(caseData, activeMode === 'live'));

  if (activeMode === 'replay') {
    const jev = caseResult(caseData.id, 'jev', activeRound);
    const qwen = caseResult(caseData.id, 'qwen', activeRound);
    grid.append(decisionRail(jev?.choices, jev?.jevAnswers, 'Jev decisions'));
    workbenchView.append(grid, replayComparison(caseData, jev, qwen));
  } else {
    grid.append(decisionRail(liveResult?.decisions, null, liveResult ? 'Live decisions' : 'Decision rail'));
    workbenchView.append(grid);
    renderLiveResult(workbenchView);
  }
}

function summaryTable() {
  const panel = element('section', 'data-panel');
  const head = element('div', 'panel-head');
  const copy = element('div');
  copy.append(element('h2', '', 'Task medians and correctness'));
  copy.append(element('p', '', 'Every task has 12 unique cases, repeated three times per provider. Lower median latency wins within a task.'));
  head.append(copy, badge(`${evidence.completed.pairedTrials} paired trials`, 'neutral'));
  panel.append(head);

  const wrap = element('div', 'table-wrap');
  const table = document.createElement('table');
  const thead = document.createElement('thead');
  const headerRow = document.createElement('tr');
  for (const label of ['Task', 'Provider', 'Cases × runs', 'Median', 'p95', 'Exact / ID', 'Semantic']) headerRow.append(element('th', '', label));
  thead.append(headerRow);
  const tbody = document.createElement('tbody');

  for (const [task, data] of Object.entries(evidence.summary)) {
    const medians = Object.values(data.providers).map(provider => provider.medianMs);
    const fastest = Math.min(...medians);
    for (const [providerName, provider] of Object.entries(data.providers)) {
      const row = document.createElement('tr');
      row.append(element('td', 'task-name', formatTask(task)));
      row.append(element('td', 'provider-name', providerName === 'jev' ? 'Jev' : 'Qwen'));
      row.append(element('td', '', '12 × 3'));
      const medianCell = element('td', `numeric${provider.medianMs === fastest ? ' fastest' : ''}`, `${provider.medianMs} ms${provider.medianMs === fastest ? ' fastest' : ''}`);
      row.append(medianCell);
      row.append(element('td', 'numeric', `${provider.p95Ms} ms`));
      row.append(element('td', 'numeric', `${provider.exactCorrect}/${provider.n}  ${formatPercent(provider.exactCorrect, provider.n)}`));
      row.append(element('td', 'numeric', `${provider.semanticCorrect}/${provider.n}  ${formatPercent(provider.semanticCorrect, provider.n)}`));
      tbody.append(row);
    }
  }
  table.append(thead, tbody);
  wrap.append(table);
  panel.append(wrap);
  panel.append(element('p', 'evidence-note', 'For word sense, Exact / ID requires the benchmark option identifier. Semantic correctness also accepts a meaning-equivalent answer. Qwen is 30/36 by ID and 36/36 semantically on that task.'));
  return panel;
}

function ledgerPanel() {
  const panel = element('section', 'data-panel');
  const head = element('div', 'panel-head');
  const copy = element('div');
  copy.append(element('h2', '', 'Case and repetition ledger'));
  copy.append(element('p', '', 'Inspect all 36 cases and all three measured repetitions without collapsing provider results.'));
  head.append(copy);
  panel.append(head);

  const controls = element('div', 'ledger-controls control-row');
  const taskSelect = document.createElement('select');
  setSelectOptions(taskSelect, [
    { value: 'all', label: 'All 36 cases' },
    ...Object.keys(TASK_LABELS).map(task => ({ value: task, label: `${formatTask(task)}, 12 cases` }))
  ], ledgerTask);
  taskSelect.addEventListener('change', () => { ledgerTask = taskSelect.value; renderEvidence(); });

  const roundSelect = document.createElement('select');
  setSelectOptions(roundSelect, [
    { value: 'all', label: 'All repetitions' },
    { value: '1', label: 'Repetition 1' },
    { value: '2', label: 'Repetition 2' },
    { value: '3', label: 'Repetition 3' }
  ], ledgerRound);
  roundSelect.addEventListener('change', () => { ledgerRound = roundSelect.value; renderEvidence(); });
  controls.append(createField('Task', taskSelect), createField('Run', roundSelect));
  panel.append(controls);

  const cases = filteredCases(ledgerTask);
  const rounds = ledgerRound === 'all' ? [1, 2, 3] : [Number(ledgerRound)];
  const wrap = element('div', 'table-wrap');
  const table = document.createElement('table');
  const thead = document.createElement('thead');
  const header = document.createElement('tr');
  for (const label of ['Case', 'Task', 'Source', 'Run', 'Jev', 'Jev exact', 'Qwen', 'Qwen exact']) header.append(element('th', '', label));
  thead.append(header);
  const tbody = document.createElement('tbody');
  for (const item of cases) {
    for (const round of rounds) {
      const jev = caseResult(item.id, 'jev', round);
      const qwen = caseResult(item.id, 'qwen', round);
      const row = document.createElement('tr');
      row.append(element('td', 'case-code', item.id));
      row.append(element('td', '', formatTask(item.task)));
      row.append(element('td', 'case-source', item.state.source));
      row.append(element('td', 'numeric', round));
      row.append(element('td', 'numeric', jev ? `${jev.elapsedMs} ms` : 'Missing'));
      row.append(element('td', '', jev?.correct ? 'Yes' : 'No'));
      row.append(element('td', 'numeric', qwen ? `${qwen.elapsedMs} ms` : 'Missing'));
      row.append(element('td', '', qwen?.correct ? 'Yes' : 'No'));
      tbody.append(row);
    }
  }
  table.append(thead, tbody);
  wrap.append(table);
  panel.append(wrap);
  return panel;
}

function renderEvidence() {
  evidenceView.replaceChildren();
  evidenceView.append(element('p', 'evidence-intro', 'Measured replay data is shown directly from evidence.json. The table includes tasks where Qwen has the lower median and does not reduce sense evaluation to identifier matching.'));
  evidenceView.append(element('p', 'evidence-intro', 'Caveat: these are authored synthetic cases from one location and time window. Repeated prompts may benefit from provider caching; this is not a measure of production accuracy, end-to-end translation latency, or audio latency.'));
  evidenceView.append(summaryTable(), ledgerPanel());
}

function renderIntegration() {
  integrationView.replaceChildren();
  integrationView.append(element('p', 'integration-intro', 'Keep decisions and generation separate. Jev classifies the turn once; the application then follows the returned route and reviews any generated translation.'));

  const flow = element('section', 'integration-panel');
  const flowHead = element('div', 'panel-head');
  const flowCopy = element('div');
  flowCopy.append(element('h2', '', 'One decision batch, three routes, and review'));
  flowCopy.append(element('p', '', 'Action, memory, register, and sense are returned together before any optional translation call. Invalid or uncertain gate data is held for review.'));
  flowHead.append(flowCopy);
  const routes = element('div', 'route-list');
  const routeData = [
    ['Clarify', 'Ask for the missing referent or sense. Do not generate a confident translation from ambiguous input.'],
    ['Reviewed memory hit', 'Return the stored Dutch phrase only after the full meaning and required register match.'],
    ['Qwen on a miss', 'Generate when no memory entry fits, then review the free-form translation. It is not certified by the decision result.']
  ];
  for (const [title, text] of routeData) {
    const route = element('article', 'route');
    route.append(element('h3', '', title), element('p', '', text));
    routes.append(route);
  }
  flow.append(flowHead, routes);
  integrationView.append(flow);

  const process = element('section', 'integration-panel');
  const processList = element('ol', 'flow-list');
  for (const [title, text] of [
    ['Send the turn once', 'Text, context, and choice criteria go to Jev in one batch call.'],
    ['Follow the route', 'Clarify, use a reviewed memory hit, or call Qwen only when generation is needed.'],
    ['Review generated text', 'A new free-form translation remains an application output that needs review, not a certified fact.']
  ]) {
    const item = element('li', 'flow-step');
    item.append(element('strong', '', title), element('p', '', text));
    processList.append(item);
  }
  process.append(processList);
  integrationView.append(process);

  const codePanel = element('section', 'integration-panel');
  const codeHead = element('div', 'code-head');
  codeHead.append(element('span', '', 'Minimal server-side usage'));
  const copyButton = element('button', 'secondary', 'Copy code');
  copyButton.type = 'button';
  const snippet = `import {createInterpreter} from './src/interpreter.mjs';\nconst app=createInterpreter({jevKey:process.env.TYPESAFE_API_KEY,qwenKey:process.env.NEBIUS_API_KEY});\nawait app.interpret({text:'Would you mind saying that again?',context:'Formal singular address.',source:'en',target:'nl'});`;
  copyButton.addEventListener('click', async () => {
    try {
      await navigator.clipboard.writeText(snippet);
      copyButton.textContent = 'Copied';
      announce('Integration code copied.');
      window.setTimeout(() => { copyButton.textContent = 'Copy code'; }, 1600);
    } catch {
      announce('Clipboard access was unavailable. Select the code manually.');
    }
  });
  codeHead.append(copyButton);
  const pre = document.createElement('pre');
  const code = document.createElement('code');
  code.textContent = snippet;
  pre.append(code);
  codePanel.append(codeHead, pre);
  integrationView.append(codePanel);

  const contract = element('section', 'integration-panel');
  const contractHead = element('div', 'panel-head');
  const contractCopy = element('div');
  contractCopy.append(element('h2', '', 'Browser contract'));
  contractCopy.append(element('p', '', 'Keys remain server-side. The browser uses same-origin JSON endpoints only.'));
  contractHead.append(contractCopy);
  const grid = element('div', 'contract-grid');
  const status = element('div');
  status.append(element('h3', '', 'GET /api/status'), element('p', '', 'Reports live availability, configured providers, model, call cap, and remaining calls.'));
  const interpret = element('div');
  interpret.append(element('h3', '', 'POST /api/interpret'), element('p', '', 'Accepts English text and context and returns route, decisions, optional Dutch output, and measured timing.'));
  grid.append(status, interpret);
  contract.append(contractHead, grid);
  integrationView.append(contract);
}

async function switchView(nextView) {
  if (activeView === nextView) return;
  invalidateVoiceOperations();
  invalidateLiveTurn(false);
  await stopActiveRecording(true);
  activeView = nextView;
  const titles = {
    workbench: ['Decision workbench', 'Inspect one interpreter turn'],
    evidence: ['Recorded benchmark', 'Read the complete evidence'],
    integration: ['Interpreter contract', 'Connect decisions to translation']
  };
  viewContext.textContent = titles[nextView][0];
  viewTitle.textContent = titles[nextView][1];
  for (const button of navButtons) {
    const selected = button.dataset.view === nextView;
    button.classList.toggle('is-active', selected);
    if (selected) button.setAttribute('aria-current', 'page');
    else button.removeAttribute('aria-current');
  }
  workbenchView.hidden = nextView !== 'workbench';
  evidenceView.hidden = nextView !== 'evidence';
  integrationView.hidden = nextView !== 'integration';
  history.replaceState(null, '', `#${nextView}`);
  document.querySelector('#main-content').focus({ preventScroll: true });
  announce(`${titles[nextView][1]} view opened.`);
}

async function fetchLiveStatus() {
  try {
    const response = await fetch('/api/status', { headers: { Accept: 'application/json' } });
    if (!response.ok) throw Error(`Status endpoint returned ${response.status}.`);
    liveStatus = await response.json();
  } catch (error) {
    liveStatus = {
      liveEnabled: false,
      jevConfigured: false,
      qwenConfigured: false,
      model: null,
      maxCalls: null,
      remainingCalls: null,
      unavailableReason: error.message
    };
  }
}

async function initialize() {
  for (const button of navButtons) button.addEventListener('click', () => switchView(button.dataset.view));
  document.querySelector('.brand').addEventListener('click', event => {
    event.preventDefault();
    switchView('workbench');
  });
  try {
    const [evidenceResponse] = await Promise.all([
      fetch('./evidence.json', { headers: { Accept: 'application/json' } }),
      fetchLiveStatus()
    ]);
    if (!evidenceResponse.ok) throw Error(`Evidence request returned ${evidenceResponse.status}.`);
    evidence = await evidenceResponse.json();
    liveText = selectedCase().state.source;
    liveContext = selectedCase().state.context;
    datasetStamp.textContent = `${formatDate(evidence.completed.completedAt)}, ${evidence.completed.pairedTrials} paired trials`;
    renderWorkbench();
    renderEvidence();
    renderIntegration();

    const requestedView = location.hash.slice(1);
    if (['evidence', 'integration'].includes(requestedView)) await switchView(requestedView);
    announce('Jev Relay recorded evidence loaded.');
  } catch (error) {
    workbenchView.replaceChildren(element('div', 'error-box', `The recorded evidence could not be loaded. ${error.message || ''}`));
    datasetStamp.textContent = 'Evidence unavailable';
    announce('The recorded evidence could not be loaded.');
  }
}

if ('speechSynthesis' in window) {
  refreshDutchVoice();
  window.speechSynthesis.addEventListener?.('voiceschanged', refreshDutchVoice);
}

window.addEventListener('beforeunload', () => {
  window.speechSynthesis?.cancel();
  if (recorder) recorder.stop(true);
});

initialize();
