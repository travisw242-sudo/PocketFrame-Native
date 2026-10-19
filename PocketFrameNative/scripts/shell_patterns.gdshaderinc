vec3 shell_pattern(vec2 uv, int motif, vec3 base, vec3 accent) {
    if (motif==2) {
        float wave=sin(uv.x*17.0+sin(uv.y*6.0)*1.4+uv.y*21.0);
        return mix(base,accent,smoothstep(.55,.72,wave)*.8);
    }
    if (motif==3) {
        float level=uv.y+sin(uv.x*7.0)*.05;
        return mix(base,accent,smoothstep(.30,.32,fract(level*3.0))*.7);
    }
    if (motif==4) {
        vec2 p=(uv-.5)*vec2(1.7,1.0);
        float diamond=abs(p.x)+abs(p.y);
        float lines=1.0-smoothstep(.009,.014,abs(fract(diamond*3.0)-.5));
        return mix(base,accent,lines);
    }
    if (motif==5) {
        vec2 p=fract(uv*vec2(7.0,4.0))-.5;
        p=mat2(vec2(.8,-.6),vec2(.6,.8))*p;
        float leaf=1.0-smoothstep(.94,1.02,length(p*vec2(4.0,2.0)));
        return mix(base,accent,leaf*.7);
    }
    if (motif==6) {
        float ribbon=sin(uv.x*8.0+sin(uv.y*7.0)*2.0+uv.y*3.0)*.5+.5;
        return mix(base,accent,pow(ribbon,3.0)*.85);
    }
    if (motif==7) {
        vec2 cell=floor(uv*vec2(17.0,10.0));
        float seed=fract(sin(dot(cell,vec2(127.1,311.7)))*43758.5453);
        vec2 p=fract(uv*vec2(17.0,10.0))-.5;
        float chip=(1.0-smoothstep(.17,.20,abs(p.x+seed*p.y)+abs(p.y*.7)))*step(.3,seed);
        return mix(base,mix(accent,vec3(.27,.40,.40),step(.75,seed)),chip);
    }
    if (motif==8) {
        vec2 p=(uv-.5)*vec2(1.7,1.0);
        float orbit=1.0-smoothstep(.005,.010,abs(length(p)-.28));
        orbit=max(orbit,1.0-smoothstep(.005,.010,abs(length(p)-.42)));
        float moon=1.0-smoothstep(.04,.045,length(p-vec2(.26,.10)));
        return mix(base,accent,max(orbit*.75,moon));
    }
    vec2 p=fract(uv*vec2(9.0,6.0));
    float circuit=(1.0-smoothstep(.018,.035,abs(p.x-.5)))*step(p.y,.7);
    circuit=max(circuit,(1.0-smoothstep(.018,.035,abs(p.y-.7)))*step(.5,p.x));
    return mix(base,accent,circuit*.55);
}
