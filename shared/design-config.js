/* Single editable design configuration. Numeric dimensions are CSS px unless named otherwise. */
globalThis.PIKO_DESIGN = {
  schemaVersion: 1,
  colors: {name:'Cobalt',primary:'#2956B8',tint:'#E7EEFC',bg:'#F5F7FB',surface:'#FFFFFF',ink:'#1E293B',muted:'#526177',onPrimary:'#FFFFFF',danger:'#B42318',success:'#166534'},
  spacing: {'1':4,'2':8,'3':12,'4':16,'5':20,'6':24,'8':32},
  typography: {family:'system-ui,-apple-system,sans-serif',body:16,small:13,label:14,title:29},
  radii: {card:16,dialog:20},
  controls: {largeHeight:48,contentWidth:760,motionFastMs:180},
  components: {
    buttons: {variant:'soft',radius:24,height:44,weight:700,padding:14},
    dropdowns: {gap:8,height:44,radius:11,padding:12,weight:400}
  }
};
