/* Single editable design configuration. Numeric dimensions are CSS px unless named otherwise. */
globalThis.PIKO_DESIGN = {
  schemaVersion: 1,
  colors: {name:'Cobalt',primary:'#2956B8',tint:'#E7EEFC',bg:'#F5F7FB',surface:'#FFFFFF',ink:'#1E293B',muted:'#526177',onPrimary:'#FFFFFF',danger:'#B42318',success:'#166534'},
  spacing: {'1':4,'2':8,'3':12,'4':16,'5':20,'6':24,'8':32},
  typography: {family:'system-ui,-apple-system,sans-serif',body:16,small:13,label:14,title:29,titleWeight:700},
  radii: {card:16,dialog:20},
  controls: {largeHeight:48,contentWidth:760,motionFastMs:180},
  layout: {pagePadding:24,mobilePadding:18,pageTop:20,mobileBreakpoint:680},
  states: {borderWidth:1,borderInkOpacity:0.14,disabledOpacity:0.5,focusWidth:3,focusOffset:3},
  components: {
    dialogs: {maxWidth:430,titleSize:20,backdropColor:'#15251c',backdropOpacity:0.5333333333333333},
    icons: {size:20},
    checkboxes: {size:24,paddingY:10},
    reviewGrading: {gap:10,topMargin:18,paddingX:8,paddingY:12,weight:650},
    reviewContext: {gap:14,topMargin:16,compactBreakpoint:400,compactSize:12,lineHeight:1.5},
    progress: {height:7,radius:9,marginY:16},
    reviewSummary: {metricSize:36,metricLineHeight:1.15,labelLineHeight:1.5},
    headings: {titleMargin:7},
    settings: {fieldMarginY:17},
    sectionHeading: {size:17,weight:700,topMargin:27,bottomMargin:14,gap:12},
    emptyState: {descriptionLineHeight:1.6,descriptionSize:15},
    learningCard: {minHeight:290,promptSize:37,promptWeight:750,bottomPadding:58,answerPromptSize:22,answerPromptWeight:500,answerSize:37,answerWeight:650,answerGap:18,dividerWidthFactor:0.64,dividerInkOpacity:0.15,cueSize:12,cueWeight:400,cueIconSize:16,cueGap:7,cueRight:18,cueBottom:16},
    languageBadge: {size:42,radius:12,fontSize:15,weight:800,letterSpacingEm:0.03},
    entryStack: {previewGap:5,previewTop:14,numberSize:12,statusSize:11,compactMinHeight:100,metaLineHeight:1.5,stateMotionMs:200},
    entryHeader: {gap:10,titleSize:22,compactTitleSize:18,actionPadding:10,compactBreakpoint:400,backWeight:750,titleLetterSpacing:-1},
    swipe: {revealDistance:60,axisDominance:1.5},
    inlineVocabulary: {compactBreakpoint:420,captionSize:11},
    cards: {padding:19},
    fields: {padding:13,radius:12,labelSize:12,labelWeight:750},
    buttons: {variant:'soft',radius:24,height:44,weight:700,padding:14},
    dropdowns: {gap:8,height:44,radius:11,padding:12,weight:400}
  }
};
