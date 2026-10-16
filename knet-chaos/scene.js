/* KNET CHAOS: local Three.js scene, original procedural clay models. */
(function () {
  'use strict';
  const T = window.THREE;
  const P = window.KnetPhysics;
  const COLORS = ['#49ddc8', '#ee80c7', '#b9eb53', '#aa8bfa', '#ffac66', '#7bc7f4'];
  let seed = 12345;
  function rand() { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; }
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

  class KnetScene {
    constructor(container) {
      this.container = container;
      this.renderer = new T.WebGLRenderer({ antialias: true, alpha: true, powerPreference: 'high-performance' });
      this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.8));
      this.renderer.shadowMap.enabled = true;
      this.renderer.shadowMap.type = T.PCFSoftShadowMap;
      this.renderer.outputColorSpace = T.SRGBColorSpace;
      this.renderer.toneMapping = T.ACESFilmicToneMapping;
      this.renderer.toneMappingExposure = 1.32;
      container.appendChild(this.renderer.domElement);
      this.scene = new T.Scene();
      this.scene.fog = new T.Fog('#39244f', 28, 60);
      this.camera = new T.OrthographicCamera(-4.8, 4.8, 8.5, -8.5, .1, 100);
      this.camera.position.set(0, 2.6, 23);
      this.camera.lookAt(0, .4, 0);
      this.scene.add(new T.HemisphereLight('#d9d3ff', '#34204d', 2.1));
      const key = new T.DirectionalLight('#ffe2be', 3.8);
      key.position.set(-4, 9, 9); key.castShadow = true;
      key.shadow.mapSize.set(1024, 1024);
      Object.assign(key.shadow.camera, { left: -7, right: 7, top: 8, bottom: -8, near: 1, far: 40 });
      key.shadow.bias = -.001;
      this.scene.add(key);
      const rim = new T.DirectionalLight('#ab84ff', 3.1); rim.position.set(5, 3, -4); this.scene.add(rim);
      const fill = new T.DirectionalLight('#75ffdd', 1.2); fill.position.set(-5, -1, 4); this.scene.add(fill);
      this.group = new T.Group(); this.scene.add(this.group);
      this.particles = [];
      this.clouds = [];
      this.rings = [];
      this.hazards = [];
      this.previewDots = [];
      this.padTops = [];
      this.skin = 0;
      this.effects = true;
      this.reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
      this.clayTexture = this.makeClayTexture();
      this.materials = new Map();
      this.sphereGeo = new T.SphereGeometry(1, 28, 20);
      this.smallSphereGeo = new T.SphereGeometry(1, 12, 10);
      this.makeBackground();
      this.raycaster = new T.Raycaster();
      this.plane = new T.Plane(new T.Vector3(0, 0, 1), 0);
      this.resizeObserver = new ResizeObserver(() => this.resize());
      this.resizeObserver.observe(container);
      this.resize();
    }
    makeClayTexture() {
      const canvas = document.createElement('canvas'); canvas.width = canvas.height = 128;
      const ctx = canvas.getContext('2d'); const data = ctx.createImageData(128, 128);
      for (let i = 0; i < data.data.length; i += 4) {
        const value = 145 + rand() * 70;
        data.data[i] = data.data[i + 1] = data.data[i + 2] = value; data.data[i + 3] = 255;
      }
      ctx.putImageData(data, 0, 0);
      const texture = new T.CanvasTexture(canvas); texture.wrapS = texture.wrapT = T.RepeatWrapping;
      texture.repeat.set(2, 2); return texture;
    }
    mat(color, roughness = .65, glow = false) {
      const key = color + roughness + glow;
      if (!this.materials.has(key)) this.materials.set(key, new T.MeshStandardMaterial({ color, roughness, metalness: 0, bumpMap: this.clayTexture, bumpScale: .016, emissive: glow ? color : '#000000', emissiveIntensity: glow ? .45 : 0 }));
      return this.materials.get(key);
    }
    sphere(parent, color, x, y, z, sx, sy = sx, sz = sx, roughness = .5) {
      const mesh = new T.Mesh(this.sphereGeo, this.mat(color, roughness));
      mesh.position.set(x, y, z); mesh.scale.set(sx, sy, sz); mesh.castShadow = true; mesh.receiveShadow = true; parent.add(mesh); return mesh;
    }
    blob(color) {
      const root = new T.Group();
      const body = this.sphere(root, color, 0, .015, 0, .34, .35, .29, .32);
      this.sphere(root, color, -.22, -.17, .02, .16, .13, .19, .32);
      this.sphere(root, color, .22, -.17, .02, .16, .13, .19, .32);
      const eyes = new T.Group(); root.add(eyes);
      [-1, 1].forEach(side => {
        const x = side * .115;
        this.sphere(eyes, '#fff5ef', x, .09, .25, .105, .132, .067, .2);
        this.sphere(eyes, '#271632', x + .022, .09, .304, .049, .075, .025, .17);
        this.sphere(eyes, '#ffffff', x + .008, .123, .326, .019, .024, .009, .15);
      });
      const smile = new T.Mesh(new T.TorusGeometry(.07, .018, 8, 18, Math.PI), this.mat('#492344'));
      smile.rotation.z = Math.PI; smile.position.set(.01, -.08, .291); root.add(smile);
      this.sphere(root, '#ffadbb', -.237, -.025, .23, .048, .02, .015);
      this.sphere(root, '#ffadbb', .237, -.025, .23, .048, .02, .015);
      root.userData = { body, eyes, color, smile };
      return root;
    }
    makeBackground() {
      seed = 735;
      const starsGeo = new T.BufferGeometry();
      const coords = [];
      for (let i = 0; i < 170; i++) coords.push((rand() - .5) * 35, (rand() - .5) * 32, -5 - rand() * 18);
      starsGeo.setAttribute('position', new T.Float32BufferAttribute(coords, 3));
      const stars = new T.Points(starsGeo, new T.PointsMaterial({ color: '#d0b5ff', size: .045, transparent: true, opacity: .7 }));
      this.scene.add(stars);
      for (let i = 0; i < 13; i++) {
        const cloud = new T.Group(); const color = i % 2 ? '#634881' : '#8962a1';
        for (let j = 0; j < 5; j++) this.sphere(cloud, color, (rand() - .5) * 2, (rand() - .5) * .5, (rand() - .5) * .8, .6 + rand() * .7, .4 + rand() * .4, .5);
        cloud.position.set((rand() - .5) * 23, -8 + rand() * 18, -8 - rand() * 15);
        cloud.userData.phase = rand() * 6; this.clouds.push(cloud); this.scene.add(cloud);
      }
      for (let i = 0; i < 10; i++) {
        const rock = this.platform({ x: (rand() - .5) * 21, y: (rand() - .5) * 19, w: 1 + rand() * 2.4, h: .8 + rand(), type: 'stone' }, true);
        rock.position.z = -6 - rand() * 13; rock.rotation.y = rand(); this.scene.add(rock);
      }
    }
    platform(data, background = false, goal = false) {
      const group = new T.Group(); group.position.set(data.x, data.y, 0);
      const h = data.h || .85;
      const geo = new T.CylinderGeometry(1, .72, 1, 12, 2);
      const pos = geo.attributes.position;
      for (let i = 0; i < pos.count; i++) {
        const x = pos.getX(i), y = pos.getY(i), z = pos.getZ(i);
        const noise = 1 + .045 * Math.sin(x * 14 + z * 8 + y * 5);
        pos.setXYZ(i, x * noise, y, z * noise);
      }
      geo.computeVertexNormals();
      const base = new T.Mesh(geo, this.mat(background ? '#72518b' : '#8050a4', .9));
      base.position.y = -h / 2 - .055; base.scale.set(data.w / 2, h, .61); base.castShadow = true; base.receiveShadow = true; group.add(base);
      const top = new T.Mesh(new T.CylinderGeometry(1, 1, .13, 30), this.mat(background ? '#9671ad' : '#b487cf', .82));
      top.position.y = -.065; top.scale.set(data.w / 2 + .045, 1, .66); top.receiveShadow = true; group.add(top);
      for (let i = 0; i < 3; i++) {
        const pebble = this.sphere(group, '#9870b9', (rand() - .5) * data.w * .65, .015, -.35 - rand() * .1, .09 + rand() * .07, .06, .1);
        pebble.rotation.z = rand();
      }
      if (!background) {
        const plants = new T.Group(); plants.position.set(-data.w * .34, .05, -.27);
        for (let i = 0; i < 3; i++) { const plant = this.sphere(plants, '#6ccab4', (i - 1) * .085, .08 + i % 2 * .03, 0, .035, .16 - Math.abs(i - 1) * .035, .04); plant.rotation.z = (i - 1) * -.35; }
        group.add(plants);
      }
      if (data.type === 'bounce') {
        const spring = new T.Mesh(new T.TorusGeometry(.32, .04, 8, 28), this.mat('#94ffd9', .32, true));
        spring.rotation.x = -Math.PI / 2; spring.position.y = .08; spring.scale.x = data.w / .8; group.add(spring);
        const pad = new T.Mesh(new T.CylinderGeometry(.34, .34, .09, 30), this.mat('#6be6c1', .4, true));
        pad.position.y = .05; pad.scale.x = data.w / .8; group.add(pad);
        const arrow = new T.Group();
        this.segment(arrow, new T.Vector3(-.13, .12, .05), new T.Vector3(0, .12, -.09), .035, '#e2ff8b');
        this.segment(arrow, new T.Vector3(0, .12, -.09), new T.Vector3(.13, .12, .05), .035, '#e2ff8b');
        group.add(arrow); this.padTops.push({ mesh: pad, x: data.x, y: data.y, pulse: 0 });
      }
      if (goal) {
        const band = new T.Mesh(new T.TorusGeometry(1, .028, 8, 48), this.mat('#bbff64', .3, true));
        band.rotation.x = Math.PI / 2; band.scale.set(data.w / 2 + .05, .66, 1); band.position.y = -.07; group.add(band);
        const pole = new T.Mesh(new T.CylinderGeometry(.018, .018, .8, 8), this.mat('#f8d7b0')); pole.position.set(data.w * .32, .4, -.33); group.add(pole);
        const shape = new T.Shape(); shape.moveTo(0, 0); shape.lineTo(.3, -.08); shape.lineTo(0, -.19); shape.closePath();
        const flag = new T.Mesh(new T.ShapeGeometry(shape), new T.MeshStandardMaterial({ color: '#f9ae5b', side: T.DoubleSide, roughness: .7 })); flag.position.set(data.w * .32, .78, -.32); group.add(flag);
      }
      return group;
    }
    segment(parent, start, end, radius, color) {
      const mesh = new T.Mesh(new T.CylinderGeometry(radius, radius, 1, 12), this.mat(color, .44));
      mesh.castShadow = true; parent.add(mesh); this.updateSegment(mesh, start, end); return mesh;
    }
    updateSegment(mesh, start, end) {
      const dir = end.clone().sub(start); mesh.position.copy(start).add(end).multiplyScalar(.5);
      mesh.scale.y = dir.length(); mesh.quaternion.setFromUnitVectors(new T.Vector3(0, 1, 0), dir.normalize());
    }
    clearLevel() {
      // Shared materials/spheres live for the scene; level-specific geometry is released.
      this.group.traverse(obj => { if (obj.geometry && obj.geometry !== this.sphereGeo && obj.geometry !== this.smallSphereGeo) obj.geometry.dispose(); });
      this.group.clear();
      this.rings = []; this.hazards = []; this.padTops = []; this.previewDots = [];
      this.clearParticles();
    }
    loadLevel(index, skin) {
      this.clearLevel(); this.levelIndex = index; this.level = P.LEVELS[index]; this.skin = skin;
      this.level.platforms.forEach(platform => this.group.add(this.platform(platform)));
      this.group.add(this.platform(this.level.goal, false, true));
      this.player = this.blob(COLORS[skin]); this.player.position.set(this.level.start.x, this.level.start.y, .03); this.group.add(this.player);
      this.friend = this.blob('#b8ee54'); this.friend.scale.setScalar(.86);
      this.friend.position.set(this.level.goal.x + .12, this.level.goal.y + .29, 0); this.group.add(this.friend);
      const marker = new T.Mesh(new T.TorusGeometry(.08, .022, 8, 24), this.mat('#d5ff91', .3, true));
      marker.position.set(this.level.goal.x + .12, this.level.goal.y + .95, 0); this.group.add(marker); this.goalMarker = marker;
      this.slingshot = new T.Group(); this.group.add(this.slingshot);
      const {x, y} = this.level.start;
      this.anchorLeft = new T.Vector3(x - .48, y + .06, .07);
      this.anchorRight = new T.Vector3(x + .48, y + .06, .07);
      [this.anchorLeft, this.anchorRight].forEach(anchor => {
        this.segment(this.slingshot, new T.Vector3(anchor.x, y - .45, -.03), anchor, .09, '#805799');
        this.sphere(this.slingshot, '#b690cc', anchor.x, anchor.y, anchor.z, .1, .09, .095);
      });
      this.bandLeft = this.segment(this.slingshot, this.anchorLeft, new T.Vector3(x, y, -.1), .031, '#ffb34f');
      this.bandRight = this.segment(this.slingshot, this.anchorRight, new T.Vector3(x, y, -.1), .031, '#ffb34f');
      this.level.rings.forEach(ring => {
        const mesh = new T.Mesh(new T.TorusGeometry(ring.r, .062, 12, 48), this.mat('#ffad47', .28, true));
        mesh.position.set(ring.x, ring.y, 0); this.group.add(mesh); this.rings.push(mesh);
        const light = new T.PointLight('#ffae54', 1, 3); light.position.set(ring.x, ring.y, .5); this.group.add(light);
      });
      this.level.hazards.forEach(hazard => {
        const root = new T.Group();
        this.sphere(root, '#65509d', 0, 0, 0, hazard.r, hazard.r, hazard.r, .7);
        for (let i = 0; i < 12; i++) {
          const a = i / 12 * Math.PI * 2;
          const spike = new T.Mesh(new T.ConeGeometry(.09, .22, 6), this.mat('#f7b376', .7));
          spike.position.set(Math.cos(a) * hazard.r, Math.sin(a) * hazard.r, .04);
          spike.rotation.z = a - Math.PI / 2; root.add(spike);
        }
        this.group.add(root); this.hazards.push(root);
      });
      const dotMaterial = new T.MeshBasicMaterial({color:'#eaffde', transparent:true, opacity:.8});
      for (let i = 0; i < 65; i++) { const dot = new T.Mesh(this.smallSphereGeo, dotMaterial); dot.scale.setScalar(.034); dot.visible = false; this.group.add(dot); this.previewDots.push(dot); }
      this.launchPulse = 0; this.winPulse = 0;
    }
    showPreview(points, visible) {
      this.previewDots.forEach((dot, i) => {
        const point = points[Math.floor(i * 1.5)];
        dot.visible = !!visible && !!point;
        if (point) { dot.position.set(point.x, point.y, .06); dot.scale.setScalar(.035 * (1 - i / 100)); }
      });
    }
    setSkin(index) { this.skin = index; }
    burst(x, y, color, amount = 16) {
      if (!this.effects || this.reducedMotion) return;
      for (let i = 0; i < amount; i++) {
        const mesh = new T.Mesh(this.smallSphereGeo, this.mat(color, .4));
        const size = .025 + rand() * .045; mesh.scale.setScalar(size); mesh.position.set(x, y, .15);
        this.scene.add(mesh); this.particles.push({mesh, vx:(rand()-.5)*4, vy:1+rand()*3, vz:(rand()-.5)*2, life:.6+rand()*.5, size});
      }
    }
    clearParticles() { this.particles.forEach(p => this.scene.remove(p.mesh)); this.particles = []; }
    handleEvents(events) {
      events.forEach(event => {
        if (event.type === 'ring') { this.burst(event.x,event.y,'#ffd275',20); this.rings[event.index].visible = false; }
        if (event.type === 'bounce') { this.burst(event.x,event.y,'#b0ffd3',18); this.padTops.forEach(pad => { if(Math.abs(pad.x-event.x)<1) pad.pulse=1; }); }
        if (event.type === 'win') { this.burst(event.x,event.y,'#c5ff77',32); this.burst(event.x,event.y+.3,'#f2a9e4',24); this.winPulse = 1; }
        if (event.type === 'lose') this.burst(event.x,event.y,COLORS[this.skin],12);
      });
    }
    update(state, dt, aim, aiming, time) {
      if (!this.player) return;
      const ball = state.ball;
      const idle = !this.reducedMotion ? Math.sin(time*3)*.025 : 0;
      if (state.status === 'ready') {
        // Stretch visually while aiming, but release from the fixed physics anchor.
        this.player.position.set(ball.x - (aiming ? aim.vx / 4.7 * .35 : 0), ball.y - (aiming ? aim.vy / 4.7 * .35 : 0) + (aiming ? 0 : idle), .1);
        const pull = aiming ? Math.hypot(aim.vx,aim.vy)/12 : 0;
        this.player.scale.set(1-pull*.13,1+pull*.35,1-pull*.1);
        this.player.rotation.z = aiming ? -.12 : Math.sin(time*2)*.03;
        this.bandLeft.visible = this.bandRight.visible = true;
        const center = this.player.position.clone(); center.z -= .13;
        this.updateSegment(this.bandLeft,this.anchorLeft,center); this.updateSegment(this.bandRight,this.anchorRight,center);
      } else {
        this.player.position.set(ball.x,ball.y,.08);
        this.bandLeft.visible = this.bandRight.visible = false;
        if(state.status === 'flying') {
          const stretch = clamp(Math.hypot(ball.vx,ball.vy)/22,0,.35);
          this.player.scale.set(1-stretch*.4,1+stretch,1-stretch*.4);
          this.player.rotation.z = -Math.atan2(ball.vx,Math.abs(ball.vy)+1)*.3;
        } else if(state.status === 'won') { this.player.scale.set(1.13,.8,1.1); this.player.rotation.z=-.1; }
        else { this.player.scale.set(1.4,.48,1.2); this.player.rotation.z=.12; }
      }
      const blink = Math.sin(time*1.35)>.993 ? .1 : 1;
      this.player.userData.eyes.scale.y = blink;
      this.friend.position.y = this.level.goal.y+.29+(this.reducedMotion ? 0 : Math.sin(time*3.5)*.055);
      this.friend.rotation.z = Math.sin(time*2.1)*.07;
      this.goalMarker.position.y=this.level.goal.y+1.05+Math.sin(time*2)*.06;
      this.hazards.forEach((mesh,i)=>{const point=P.hazardAt(this.level.hazards[i],state.time);mesh.position.set(point.x,point.y,0);mesh.rotation.z=state.time*.25;});
      this.rings.forEach((mesh,i)=>{mesh.visible=!state.ringHits.includes(i);mesh.rotation.y=Math.sin(time*1.5+i)*.13;});
      this.padTops.forEach(pad=>{pad.pulse=Math.max(0,pad.pulse-dt*3);pad.mesh.scale.y=1+Math.sin(pad.pulse*10)*pad.pulse*.6;});
      this.clouds.forEach(cloud=>{if(!this.reducedMotion)cloud.rotation.z=Math.sin(time*.08+cloud.userData.phase)*.03;});
      for(let i=this.particles.length-1;i>=0;i--){const p=this.particles[i];p.life-=dt;if(p.life<=0){this.scene.remove(p.mesh);this.particles.splice(i,1);continue;}p.vy-=dt*4;p.mesh.position.x+=p.vx*dt;p.mesh.position.y+=p.vy*dt;p.mesh.position.z+=p.vz*dt;p.mesh.scale.setScalar(p.size*Math.min(1,p.life*3));}
      this.renderer.render(this.scene,this.camera);
    }
    screenToWorld(clientX,clientY) {
      const rect=this.container.getBoundingClientRect();
      this.raycaster.setFromCamera(new T.Vector2((clientX-rect.left)/rect.width*2-1,-(clientY-rect.top)/rect.height*2+1),this.camera);
      const point=new T.Vector3(); this.raycaster.ray.intersectPlane(this.plane,point); return point;
    }
    worldToScreen(x,y) {
      const rect=this.container.getBoundingClientRect();const p=new T.Vector3(x,y,0).project(this.camera);
      return {x:rect.left+(p.x+1)/2*rect.width,y:rect.top+(1-p.y)/2*rect.height};
    }
    resize() {
      const w=this.container.clientWidth,h=this.container.clientHeight;if(!w||!h)return;
      this.renderer.setSize(w,h,false);const width=9.4,height=width*h/w;
      this.camera.left=-width/2;this.camera.right=width/2;this.camera.top=height/2;this.camera.bottom=-height/2;this.camera.updateProjectionMatrix();
    }
  }
  KnetScene.COLORS=COLORS; window.KnetScene=KnetScene;
})();
