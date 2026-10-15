/* Synthetic comparison fixtures only. Each preview receives an independent copy. */
(function (root) {
  function createCollections() {
    return [
      {name:'Korean Basics',targetLanguage:'ko',nativeLanguage:'de',entries:[
        {targetText:'사과',nativeText:'Apfel'},
        {targetText:'물',nativeText:'Wasser'},
        {targetText:'학교',nativeText:'Schule'},
        {targetText:'친구',nativeText:'Freund'},
        {targetText:'책',nativeText:'Buch'}
      ]},
      {name:'French A1',targetLanguage:'fr',nativeLanguage:'de',entries:[
        {targetText:'pomme',nativeText:'Apfel'},
        {targetText:'eau',nativeText:'Wasser'},
        {targetText:'école',nativeText:'Schule'}
      ]},
      {name:'English Notes',targetLanguage:'en',nativeLanguage:'de',entries:[
        {targetText:'apple',nativeText:'Apfel'},
        {targetText:'water',nativeText:'Wasser'},
        {targetText:'school',nativeText:'Schule'}
      ]}
    ];
  }
  const languageKey = code => ({ko:'korean',fr:'french',en:'english',de:'german'}[code]);
  const api = {createCollections,languageKey};
  root.PikoSampleData = api;
  if (typeof module !== 'undefined') module.exports = api;
})(globalThis);
