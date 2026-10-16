(function () {
  'use strict';
  const $ = id => document.getElementById(id);
  const P = window.KnetPhysics;
  const SAVE_KEY = 'knet-chaos-v1';
  const SKINS = ['Minty', 'Bubblegum', 'Kiwi', 'Lavendel', 'Aprikose', 'Wolke'];
  const COLORS = ['#49ddc8','#ee80c7','#b9eb53','#aa8bfa','#ffac66','#7bc7f4'];
  const freshSave = () => ({stars:Array(6).fill(0),skin:0,sound:true,effects:true,current:0});
  let save = freshSave(), storageAvailable = true;
  try {
    const loaded = JSON.parse(localStorage.getItem(SAVE_KEY) || 'null');
    if(loaded && Array.isArray(loaded.stars)) {
      save.stars = save.stars.map((_,i)=>Math.max(0,Math.min(3,Math.floor(Number(loaded.stars[i])||0))));
      save.skin = Math.max(0,Math.min(5,Math.floor(Number(loaded.skin)||0)));
      save.current = Math.max(0,Math.min(5,Math.floor(Number(loaded.current)||0)));
      save.sound = loaded.sound !== false; save.effects = loaded.effects !== false;
    }
  } catch (_) { storageAvailable = false; }
  let scene, state, active = false, paused = false, currentLevel = save.current;
  let attempts = 1, aiming = false, dragStart = null, pointerId = null;
  let aim = {vx:3.6,vy:7.1}, help = true, roundToken = 0, resultPending = false;
  let previousFrame = 0, gameTime = 0, toastTimer = null, audio = null;
  let previewFrame = 0, offlineReady = false;
  const modal = $('modal');

  function persist() {
    try { localStorage.setItem(SAVE_KEY,JSON.stringify(save)); }
    catch (_) { storageAvailable = false; }
    updateHome();
  }
  function updateHome() {
    $('total-stars').textContent = save.stars.reduce((sum,value)=>sum+value,0);
    $('continue-level').textContent = 'Level '+(save.current+1);
    $('continue-name').textContent = P.LEVELS[save.current].name;
    const blob=$('looks-card').querySelector('.mini-blob');
    blob.style.background=`radial-gradient(ellipse at 30% 20%,#fff9,${COLORS[save.skin]} 45%,${COLORS[save.skin]} 85%)`;
  }
  function initAudio() {
    if(!save.sound)return;
    try { const Audio = window.AudioContext || window.webkitAudioContext; if(!audio && Audio)audio=new Audio(); if(audio?.state==='suspended')audio.resume(); }catch(_){}
  }
  function note(frequency,duration=.12,delay=0,type='sine',gain=.08) {
    if(!save.sound||!audio)return;
    try {const oscillator=audio.createOscillator(),volume=audio.createGain();oscillator.type=type;oscillator.frequency.value=frequency;volume.gain.setValueAtTime(0,audio.currentTime+delay);volume.gain.linearRampToValueAtTime(gain,audio.currentTime+delay+.01);volume.gain.exponentialRampToValueAtTime(.001,audio.currentTime+delay+duration);oscillator.connect(volume);volume.connect(audio.destination);oscillator.start(audio.currentTime+delay);oscillator.stop(audio.currentTime+delay+duration+.02);}catch(_){}
  }
  function sound(type) {
    if(type==='launch'){note(310,.08,0,'sine',.06);note(470,.11,.045,'sine',.04);}
    if(type==='ring'){note(880,.15);note(1174,.18,.07);}
    if(type==='bounce'){note(185,.1,0,'triangle');note(430,.13,.06,'sine');}
    if(type==='win'){[523,659,784,1046].forEach((n,i)=>note(n,.3,i*.1));}
    if(type==='lose'){note(140,.2,0,'triangle',.06);note(95,.14,.09,'sine',.03);}
    if(type==='click')note(600,.045,0,'sine',.025);
  }
  function toast(message) {
    clearTimeout(toastTimer);$('toast').textContent=message;$('toast').classList.add('visible');
    toastTimer=setTimeout(()=>$('toast').classList.remove('visible'),1600);
  }
  function ensureScene() {
    if(scene)return true;
    try {if(!window.THREE)throw new Error('Die 3D-Datei fehlt.');scene=new window.KnetScene($('scene'));scene.effects=save.effects;return true;}
    catch(error){$('error-message').hidden=false;$('error-message').textContent='Die 3D-Ansicht konnte nicht starten. Bitte öffne das Spiel in Chrome, Edge, Firefox oder Safari mit aktivierter Hardwarebeschleunigung. '+error.message;return false;}
  }
  function beginLevel(index, resetAttempts=true) {
    closeModal(); active=true;paused=false;currentLevel=index;save.current=index;persist();
    $('home').hidden=true;$('game').hidden=false;
    if(!ensureScene())return;
    if(resetAttempts)attempts=1;
    roundToken++;resultPending=false;aiming=false;dragStart=null;pointerId=null;
    state=P.createState(index);scene.loadLevel(index,save.skin);scene.resize();
    scene.effects=save.effects;scene.showPreview([],false);
    $('result').hidden=true;$('toast').classList.remove('visible');
    $('game-level').textContent=`LEVEL ${index+1} / ${P.LEVELS.length}`;
    $('level-name').textContent=P.LEVELS[index].name;
    $('hint-detail').textContent=P.LEVELS[index].hint;
    $('aim-hint').hidden=false;
    $('angle').value=63;$('power').value=7.9;setAimFromSliders(false);
    updateStatus();initAudio();previousFrame=performance.now();
  }
  function retry() {if(!active)return;attempts++;beginLevel(currentLevel,false);sound('click');}
  function goHome() {
    active=false;paused=false;aiming=false;roundToken++;resultPending=false;closeModal();
    $('game').hidden=true;$('home').hidden=false;$('result').hidden=true;updateHome();
    if(scene)scene.clearParticles();
  }
  function updateStatus() {
    $('rings-status').textContent=`◉ ${state.ringHits.length} / ${P.LEVELS[currentLevel].rings.length}`;
    $('shots-status').textContent=`${attempts}. Versuch`;
  }
  function refreshPreview() {
    if(!scene||!state)return;
    scene.showPreview(P.predict(currentLevel,aim.vx,aim.vy,state.time),help && state.status==='ready' && (aiming || !$('accessible-controls').hidden));
  }
  function shoot() {
    if(!state||paused||modal.open||state.status!=='ready')return;
    initAudio();if(!P.launch(state,aim.vx,aim.vy))return;
    aiming=false;dragStart=null;scene.showPreview([],false);$('aim-hint').hidden=true;sound('launch');
  }
  function setAimFromSliders(preview=true) {
    const angle=Number($('angle').value)*Math.PI/180,force=Number($('power').value);
    aim={vx:Math.cos(angle)*force,vy:Math.sin(angle)*force};if(preview)refreshPreview();
  }
  $('scene').addEventListener('pointerdown',event=>{
    if(!active||paused||modal.open||state.status!=='ready'||event.button>0)return;
    const point=scene.screenToWorld(event.clientX,event.clientY);
    if(Math.hypot(point.x-state.ball.x,point.y-state.ball.y)>1.25){toast('Starte mit dem Finger auf deinem Blob.');return;}
    initAudio();event.preventDefault();pointerId=event.pointerId;event.currentTarget.setPointerCapture(pointerId);
    dragStart=point;aiming=true;aim={vx:0,vy:0};$('hint-detail').textContent='Die Punkte zeigen deinen Flug. Lass los!';
  });
  $('scene').addEventListener('pointermove',event=>{
    if(!aiming||event.pointerId!==pointerId||!dragStart)return;
    const point=scene.screenToWorld(event.clientX,event.clientY);
    let vx=(dragStart.x-point.x)*4.7,vy=(dragStart.y-point.y)*4.7;
    const length=Math.hypot(vx,vy);if(length>12){vx*=12/length;vy*=12/length;}
    aim={vx,vy};refreshPreview();
  });
  $('scene').addEventListener('pointerup',event=>{
    if(event.pointerId!==pointerId||!aiming)return;
    if(event.currentTarget.hasPointerCapture(event.pointerId))event.currentTarget.releasePointerCapture(event.pointerId);
    pointerId=null;
    if(Math.hypot(aim.vx,aim.vy)<.5){aiming=false;dragStart=null;scene.showPreview([],false);return;}
    shoot();
  });
  function cancelAim(){aiming=false;dragStart=null;pointerId=null;if(scene)scene.showPreview([],false);}
  $('scene').addEventListener('pointercancel',cancelAim);
  $('scene').addEventListener('contextmenu',event=>event.preventDefault());
  $('play').addEventListener('click',()=>beginLevel(save.current));
  $('back-home').addEventListener('click',goHome);
  $('nav-home').addEventListener('click',goHome);
  $('retry').addEventListener('click',retry);
  $('aim-help').addEventListener('click',()=>{help=!help;$('aim-help').classList.toggle('selected',help);$('aim-help').setAttribute('aria-pressed',String(help));refreshPreview();});
  $('keyboard-toggle').addEventListener('click',()=>{$('accessible-controls').hidden=!$('accessible-controls').hidden;setAimFromSliders();});
  $('angle').addEventListener('input',()=>setAimFromSliders());$('power').addEventListener('input',()=>setAimFromSliders());
  $('launch-button').addEventListener('click',shoot);
  document.addEventListener('keydown',event=>{
    if(!active||modal.open||paused||event.target.matches('input,button'))return;
    if(event.code==='Space'){event.preventDefault();shoot();}
    if(event.code==='KeyR'){event.preventDefault();retry();}
    if(event.code==='Escape'){event.preventDefault();showPause();}
    if(state.status==='ready' && ['ArrowLeft','ArrowRight','ArrowUp','ArrowDown'].includes(event.code)){
      event.preventDefault();$('accessible-controls').hidden=false;
      if(event.code==='ArrowLeft')$('angle').value=Math.min(85,Number($('angle').value)+2);
      if(event.code==='ArrowRight')$('angle').value=Math.max(20,Number($('angle').value)-2);
      if(event.code==='ArrowUp')$('power').value=Math.min(12,Number($('power').value)+.2);
      if(event.code==='ArrowDown')$('power').value=Math.max(3,Number($('power').value)-.2);
      setAimFromSliders();
    }
  });
  function finishRound(won) {
    if(resultPending)return;resultPending=true;cancelAim();
    const token=roundToken;
    if(won){
      const rings=P.LEVELS[currentLevel].rings.length;
      const rating=1+(state.ringHits.length===rings?1:0)+(attempts<=2?1:0);
      save.stars[currentLevel]=Math.max(save.stars[currentLevel],rating);
      save.current=Math.min(5,currentLevel+1);persist();
      $('result-eyebrow').textContent='GUT GELANDET!';$('result-title').textContent='Freund gerettet!';$('result-icon').textContent='✦';
      $('result-stars').innerHTML=starsHTML(rating);$('result-stars').setAttribute('aria-label',`${rating} von 3 Sternen`);
      $('result-message').textContent=currentLevel===5?'Alle sechs Parcours sind spielbar. Hol dir jetzt deine fehlenden Sterne!':`${state.ringHits.length} von ${rings} Ringen · ${attempts} ${attempts===1?'Versuch':'Versuche'}. Dein Blob-Freund freut sich!`;
      $('result-primary').textContent=currentLevel===5?'ZUR LEVELAUSWAHL':'NÄCHSTES LEVEL →';
      $('result-primary').onclick=()=>currentLevel===5?showLevels():beginLevel(currentLevel+1);
      $('result-secondary').textContent='Noch mal · Sterne verbessern';$('result-secondary').onclick=()=>beginLevel(currentLevel);
    }else{
      $('result-eyebrow').textContent='UPS. DAS WAR KNET-KUNST.';$('result-title').textContent='Ein kleiner Platsch.';$('result-icon').textContent='〰';$('result-stars').innerHTML='';$('result-stars').setAttribute('aria-label','');
      const message=state.lossReason==='hazard'?'Die Kugel war im Weg. Versuch es mit einem anderen Bogen.':state.lossReason==='platform'?'Fast! Die grüne Insel ist dein Ziel. Ändere Winkel oder Kraft.':'Dein Blob ist weich gelandet. Weniger Kraft oder ein anderer Winkel?';
      $('result-message').textContent=message;$('result-primary').textContent='NOCH MAL';$('result-primary').onclick=retry;
      $('result-secondary').textContent='Zur Startseite';$('result-secondary').onclick=goHome;
    }
    setTimeout(()=>{if(token===roundToken&&active){$('result').hidden=false;$('result-primary').focus({preventScroll:true});}},won?850:650);
  }
  function starsHTML(amount){return Array.from({length:3},(_,i)=>`<span${i>=amount?' class="empty"':''}>★</span>`).join('');}
  function openModal(title,kicker){cancelAim();paused=active;$('modal-title').textContent=title;$('modal-kicker').textContent=kicker;$('modal-content').replaceChildren();if(!modal.open)modal.showModal();}
  function closeModal(){if(modal.open)modal.close();paused=false;previousFrame=performance.now();}
  $('close-modal').addEventListener('click',closeModal);
  modal.addEventListener('close',()=>{paused=false;previousFrame=performance.now();});
  modal.addEventListener('click',event=>{if(event.target===modal){const r=modal.getBoundingClientRect();if(event.clientX<r.left||event.clientX>r.right||event.clientY<r.top||event.clientY>r.bottom)closeModal();}});
  function showLevels(){
    openModal('Dein Abenteuer','SECHS KLEINE CHAOS-MOMENTE');
    $('modal-content').innerHTML='<p class="modal-intro">Jeder Freund wartet auf seinen Rettungssprung. Alle sechs Levels kannst du frei ausprobieren.</p><div class="level-grid"></div>';
    const grid=$('modal-content').querySelector('.level-grid');
    P.LEVELS.forEach((level,index)=>{const button=document.createElement('button');button.className='level-tile'+(save.current===index?' current':'');button.innerHTML=`<span class="level-number">0${index+1}</span><strong>${level.name}</strong><span class="level-rating">${starsHTML(save.stars[index])}</span>`;button.setAttribute('aria-label',`Level ${index+1}: ${level.name}, ${save.stars[index]} von 3 Sternen`);button.onclick=()=>beginLevel(index);grid.appendChild(button);});
    const info=document.createElement('p');info.className='instructions';info.textContent='Sterne: Freund retten · alle Ringe · höchstens zwei Versuche. Dein bestes Ergebnis bleibt gespeichert.';$('modal-content').appendChild(info);
  }
  function showLooks(){
    openModal('Dein Blob','KLEIN. KNETIG. GANZ DEINER.');
    $('modal-content').innerHTML='<p class="modal-intro">Sechs Farben, gleich viel Sprungkraft. Such dir deinen Lieblingsblob aus.</p><div class="skin-grid"></div>';
    const grid=$('modal-content').querySelector('.skin-grid');
    SKINS.forEach((name,index)=>{const button=document.createElement('button');button.className='skin-button'+(save.skin===index?' active':'');button.setAttribute('aria-pressed',String(save.skin===index));button.innerHTML=`<span class="mini-blob" style="background:radial-gradient(ellipse at 30% 20%,#fff9,${COLORS[index]} 45%,${COLORS[index]} 85%)"><i></i><i></i><b></b></span><strong>${name}</strong><small>${save.skin===index?'Ausgewählt':'Kostenlos'}</small>`;button.onclick=()=>{save.skin=index;persist();initAudio();sound('click');showLooks();};grid.appendChild(button);});
    const done=document.createElement('button');done.className='play-button modal-action';done.textContent='SIEHT GUT AUS';done.onclick=closeModal;$('modal-content').appendChild(done);
  }
  $('nav-levels').onclick=showLevels;$('level-card').onclick=showLevels;$('nav-looks').onclick=showLooks;$('looks-card').onclick=showLooks;
  function showSettings(){
    openModal('Einstellungen','DEIN SPIELGEFÜHL');
    $('modal-content').innerHTML=`<div class="setting-row"><div><strong>Sounds</strong><small>Platsch, Boing und kleine Erfolgstöne.</small></div><button id="sound-toggle" class="toggle ${save.sound?'on':''}" aria-pressed="${save.sound}">${save.sound?'An':'Aus'}</button></div><div class="setting-row"><div><strong>Konfetti</strong><small>Ein bisschen Glitzer beim Treffer.</small></div><button id="effects-toggle" class="toggle ${save.effects?'on':''}" aria-pressed="${save.effects}">${save.effects?'An':'Aus'}</button></div><button id="iphone-help" class="small-button install-help">Auf dem iPhone zum Home-Bildschirm hinzufügen ↗</button><p class="instructions"><b>Mit Finger oder Maus:</b> Blob berühren, nach hinten ziehen, loslassen.<br><b>Ohne Ziehen:</b> Im Spiel den Regler-Knopf öffnen. Winkel und Kraft einstellen, dann „Los!“. Pfeiltasten und Leertaste funktionieren ebenfalls.<br><b>R:</b> Neuer Versuch · <b>Esc:</b> Pause.</p><p class="settings-footer">6 Levels · lokal gespeicherte Sterne · keine Käufe oder Werbung.<br>${offlineReady?'Auch offline bereit. ':''}${storageAvailable?'Dein Fortschritt bleibt auf diesem Gerät.':'Dein Browser erlaubt aktuell kein dauerhaftes Speichern.'}</p>`;
    $('sound-toggle').onclick=()=>{save.sound=!save.sound;persist();if(save.sound){initAudio();sound('click');}showSettings();};
    $('effects-toggle').onclick=()=>{save.effects=!save.effects;if(scene)scene.effects=save.effects;persist();showSettings();};
    $('iphone-help').onclick=showInstallHelp;
  }
  function showInstallHelp(){
    openModal('Auf dein iPhone','DEIN BLOB ZIEHT EIN');
    $('modal-content').innerHTML='<p class="modal-intro">Öffne den Spiellink auf deinem iPhone in <b>Safari</b>.</p><ol class="instructions install-steps"><li>Tippe auf <b>Teilen</b> (Quadrat mit Pfeil nach oben). Je nach Safari-Ansicht findest du es im Menü „Mehr“.</li><li>Wähle <b>„Zum Home-Bildschirm“</b>.</li><li>Falls angezeigt, lass <b>„Als Web-App öffnen“</b> eingeschaltet und tippe auf <b>„Hinzufügen“</b>.</li><li>Starte <b>KNET CHAOS</b> über das neue Blob-Symbol.</li></ol><p class="settings-footer">Lade das Spiel beim ersten Start mit Internet vollständig. Danach stehen die sechs Levels auch offline bereit, solange dein Gerät die gespeicherten Spieldateien behält.</p><button id="install-done" class="play-button modal-action">ALLES KLAR</button>';
    $('install-done').onclick=closeModal;
  }
  document.querySelectorAll('.settings-open').forEach(button=>button.onclick=showSettings);
  function showPause(){
    if(!active)return;openModal('Kleine Knetpause','DEIN BLOB WARTET AUF DICH');
    $('modal-content').innerHTML='<p class="pause-copy">Alles bleibt genau hier. Bereit für den nächsten Sprung?</p><button class="play-button modal-action" id="resume">WEITERSPIELEN</button><div class="settings-actions"><button class="small-button" id="pause-settings">Einstellungen</button><button class="small-button" id="pause-home">Zur Startseite</button></div>';
    $('resume').onclick=closeModal;$('pause-settings').onclick=showSettings;$('pause-home').onclick=goHome;
  }
  $('pause').onclick=showPause;
  document.addEventListener('visibilitychange',()=>{if(document.hidden&&active&&!modal.open&&state?.status==='flying')showPause();previousFrame=performance.now();});
  function frame(now){
    const dt=Math.min(.05,(now-previousFrame)/1000||0);previousFrame=now;
    if(active&&scene&&state){
      if(!paused&&!document.hidden){
        gameTime+=dt;P.step(state,dt);
        if(state.events.length){scene.handleEvents(state.events);state.events.forEach(event=>{sound(event.type);if(event.type==='ring')toast('Schön durch den Ring!');if(event.type==='bounce')toast('Boing!');if(event.type==='win')finishRound(true);if(event.type==='lose')finishRound(false);});updateStatus();}
        if(aiming && ++previewFrame%4===0)refreshPreview();
      }
      scene.update(state,paused?0:dt,aim,aiming,gameTime);
    }
    requestAnimationFrame(frame);
  }
  updateHome();requestAnimationFrame(frame);
  if('serviceWorker' in navigator && (location.protocol==='https:' || ['localhost','127.0.0.1'].includes(location.hostname))){
    window.addEventListener('load',()=>{
      navigator.serviceWorker.register('./sw.js').then(()=>navigator.serviceWorker.ready).then(()=>{offlineReady=true;}).catch(()=>{offlineReady=false;});
    });
  }
  // Small, read-only diagnostic surface for browser QA, not an alternate game path.
  window.KnetGame=Object.freeze({snapshot:()=>({active,paused,level:currentLevel,attempts,status:state?.status,ball:state?{...state.ball}:null,rings:state?[...state.ringHits]:[],stars:[...save.stars],skin:save.skin,drawCalls:scene?.renderer.info.render.calls}),worldToScreen:(x,y)=>scene?.worldToScreen(x,y)});
})();
