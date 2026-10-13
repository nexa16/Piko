/* Adapter only: defaults are owned by design-config.js, not duplicated here. */
(() => {
 const config=globalThis.PIKO_DESIGN;
 if(!config||config.schemaVersion!==1)throw Error('Piko design configuration is missing or unsupported.');
 const root=document.documentElement;
 const set=(name,value)=>root.style.setProperty(name,String(value));
 const dimension=(name,value,min=0,max=2000,unit='px')=>{if(!Number.isFinite(value)||value<min||value>max)throw Error('Invalid design token '+name);set(name,value+unit);};
 for(const[key,value]of Object.entries(config.colors)){if(key==='name')continue;if(!/^#[0-9a-f]{6}$/i.test(value))throw Error('Invalid design color '+key);set('--piko-'+key,value);}
 for(const[key,value]of Object.entries(config.spacing))dimension('--space-'+key,value);
 if(typeof config.typography.family!=='string'||!config.typography.family.trim())throw Error('Invalid font family');
 set('--font-family',config.typography.family);
 for(const key of ['body','small','label','title'])dimension('--font-'+key,config.typography[key],8,100);
 for(const[key,value]of Object.entries(config.radii))dimension('--radius-'+key,value,0,100);
 dimension('--control-large',config.controls.largeHeight,44,100);dimension('--content-width',config.controls.contentWidth,280,2000);dimension('--motion-fast',config.controls.motionFastMs,0,2000,'ms');
 const b=config.components.buttons,d=config.components.dropdowns;
 if(!['flat','soft','outline'].includes(b.variant))throw Error('Invalid button variant');
 set('--button-style',b.variant);root.dataset.buttonStyle=b.variant;
 for(const[name,value,min,max,unit]of [['--radius-control',b.radius,0,24,'px'],['--control-height',b.height,44,60,'px'],['--button-weight',b.weight,400,750,''],['--button-padding-x',b.padding,8,28,'px'],['--field-label-gap',d.gap,4,20,'px'],['--select-height',d.height,44,60,'px'],['--select-radius',d.radius,0,24,'px'],['--select-padding-x',d.padding,8,28,'px'],['--select-weight',d.weight,400,750,'']])dimension(name,value,min,max,unit);
})();
