// ----------------------------------------------------------------------
// 1bit audio player
// We get the URL to 1bit.swf from one_bit_url.

/**
 * SWFObject v1.5: Flash Player detection and embed - http://blog.deconcept.com/swfobject/
 *
 * SWFObject is (c) 2007 Geoff Stearns and is released under the MIT License:
 * http://www.opensource.org/licenses/mit-license.php
 *
 */
if(typeof deconcept=="undefined"){var deconcept=new Object();}if(typeof deconcept.util=="undefined"){deconcept.util=new Object();}if(typeof deconcept.SWFObjectUtil=="undefined"){deconcept.SWFObjectUtil=new Object();}deconcept.SWFObject=function(_1,id,w,h,_5,c,_7,_8,_9,_a){if(!document.getElementById){return;}this.DETECT_KEY=_a?_a:"detectflash";this.skipDetect=deconcept.util.getRequestParameter(this.DETECT_KEY);this.params=new Object();this.variables=new Object();this.attributes=new Array();if(_1){this.setAttribute("swf",_1);}if(id){this.setAttribute("id",id);}if(w){this.setAttribute("width",w);}if(h){this.setAttribute("height",h);}if(_5){this.setAttribute("version",new deconcept.PlayerVersion(_5.toString().split(".")));}this.installedVer=deconcept.SWFObjectUtil.getPlayerVersion();if(!window.opera&&document.all&&this.installedVer.major>7){deconcept.SWFObject.doPrepUnload=true;}if(c){this.addParam("bgcolor",c);}var q=_7?_7:"high";this.addParam("quality",q);this.setAttribute("useExpressInstall",false);this.setAttribute("doExpressInstall",false);var _c=(_8)?_8:window.location;this.setAttribute("xiRedirectUrl",_c);this.setAttribute("redirectUrl","");if(_9){this.setAttribute("redirectUrl",_9);}};deconcept.SWFObject.prototype={useExpressInstall:function(_d){this.xiSWFPath=!_d?"expressinstall.swf":_d;this.setAttribute("useExpressInstall",true);},setAttribute:function(_e,_f){this.attributes[_e]=_f;},getAttribute:function(_10){return this.attributes[_10];},addParam:function(_11,_12){this.params[_11]=_12;},getParams:function(){return this.params;},addVariable:function(_13,_14){this.variables[_13]=_14;},getVariable:function(_15){return this.variables[_15];},getVariables:function(){return this.variables;},getVariablePairs:function(){var _16=new Array();var key;var _18=this.getVariables();for(key in _18){_16[_16.length]=key+"="+_18[key];}return _16;},getSWFHTML:function(){var _19="";if(navigator.plugins&&navigator.mimeTypes&&navigator.mimeTypes.length){if(this.getAttribute("doExpressInstall")){this.addVariable("MMplayerType","PlugIn");this.setAttribute("swf",this.xiSWFPath);}_19="<embed type=\"application/x-shockwave-flash\" src=\""+this.getAttribute("swf")+"\" width=\""+this.getAttribute("width")+"\" height=\""+this.getAttribute("height")+"\" style=\""+this.getAttribute("style")+"\"";_19+=" id=\""+this.getAttribute("id")+"\" name=\""+this.getAttribute("id")+"\" ";var _1a=this.getParams();for(var key in _1a){_19+=[key]+"=\""+_1a[key]+"\" ";}var _1c=this.getVariablePairs().join("&");if(_1c.length>0){_19+="flashvars=\""+_1c+"\"";}_19+="/>";}else{if(this.getAttribute("doExpressInstall")){this.addVariable("MMplayerType","ActiveX");this.setAttribute("swf",this.xiSWFPath);}_19="<object id=\""+this.getAttribute("id")+"\" classid=\"clsid:D27CDB6E-AE6D-11cf-96B8-444553540000\" width=\""+this.getAttribute("width")+"\" height=\""+this.getAttribute("height")+"\" style=\""+this.getAttribute("style")+"\">";_19+="<param name=\"movie\" value=\""+this.getAttribute("swf")+"\" />";var _1d=this.getParams();for(var key in _1d){_19+="<param name=\""+key+"\" value=\""+_1d[key]+"\" />";}var _1f=this.getVariablePairs().join("&");if(_1f.length>0){_19+="<param name=\"flashvars\" value=\""+_1f+"\" />";}_19+="</object>";}return _19;},write:function(_20){if(this.getAttribute("useExpressInstall")){var _21=new deconcept.PlayerVersion([6,0,65]);if(this.installedVer.versionIsValid(_21)&&!this.installedVer.versionIsValid(this.getAttribute("version"))){this.setAttribute("doExpressInstall",true);this.addVariable("MMredirectURL",escape(this.getAttribute("xiRedirectUrl")));document.title=document.title.slice(0,47)+" - Flash Player Installation";this.addVariable("MMdoctitle",document.title);}}if(this.skipDetect||this.getAttribute("doExpressInstall")||this.installedVer.versionIsValid(this.getAttribute("version"))){var n=(typeof _20=="string")?document.getElementById(_20):_20;n.innerHTML=this.getSWFHTML();return true;}else{if(this.getAttribute("redirectUrl")!=""){document.location.replace(this.getAttribute("redirectUrl"));}}return false;}};deconcept.SWFObjectUtil.getPlayerVersion=function(){var _23=new deconcept.PlayerVersion([0,0,0]);if(navigator.plugins&&navigator.mimeTypes.length){var x=navigator.plugins["Shockwave Flash"];if(x&&x.description){_23=new deconcept.PlayerVersion(x.description.replace(/([a-zA-Z]|\s)+/,"").replace(/(\s+r|\s+b[0-9]+)/,".").split("."));}}else{if(navigator.userAgent&&navigator.userAgent.indexOf("Windows CE")>=0){var axo=1;var _26=3;while(axo){try{_26++;axo=new ActiveXObject("ShockwaveFlash.ShockwaveFlash."+_26);_23=new deconcept.PlayerVersion([_26,0,0]);}catch(e){axo=null;}}}else{try{var axo=new ActiveXObject("ShockwaveFlash.ShockwaveFlash.7");}catch(e){try{var axo=new ActiveXObject("ShockwaveFlash.ShockwaveFlash.6");_23=new deconcept.PlayerVersion([6,0,21]);axo.AllowScriptAccess="always";}catch(e){if(_23.major==6){return _23;}}try{axo=new ActiveXObject("ShockwaveFlash.ShockwaveFlash");}catch(e){}}if(axo!=null){_23=new deconcept.PlayerVersion(axo.GetVariable("$version").split(" ")[1].split(","));}}}return _23;};deconcept.PlayerVersion=function(_29){this.major=_29[0]!=null?parseInt(_29[0]):0;this.minor=_29[1]!=null?parseInt(_29[1]):0;this.rev=_29[2]!=null?parseInt(_29[2]):0;};deconcept.PlayerVersion.prototype.versionIsValid=function(fv){if(this.major<fv.major){return false;}if(this.major>fv.major){return true;}if(this.minor<fv.minor){return false;}if(this.minor>fv.minor){return true;}if(this.rev<fv.rev){return false;}return true;};deconcept.util={getRequestParameter:function(_2b){var q=document.location.search||document.location.hash;if(_2b==null){return q;}if(q){var _2d=q.substring(1).split("&");for(var i=0;i<_2d.length;i++){if(_2d[i].substring(0,_2d[i].indexOf("="))==_2b){return _2d[i].substring((_2d[i].indexOf("=")+1));}}}return "";}};deconcept.SWFObjectUtil.cleanupSWFs=function(){var _2f=document.getElementsByTagName("OBJECT");for(var i=_2f.length-1;i>=0;i--){_2f[i].style.display="none";for(var x in _2f[i]){if(typeof _2f[i][x]=="function"){_2f[i][x]=function(){};}}}};if(deconcept.SWFObject.doPrepUnload){if(!deconcept.unloadSet){deconcept.SWFObjectUtil.prepUnload=function(){__flash_unloadHandler=function(){};__flash_savedUnloadHandler=function(){};window.attachEvent("onunload",deconcept.SWFObjectUtil.cleanupSWFs);};window.attachEvent("onbeforeunload",deconcept.SWFObjectUtil.prepUnload);deconcept.unloadSet=true;}}if(!document.getElementById&&document.all){document.getElementById=function(id){return document.all[id];};}var getQueryParamValue=deconcept.util.getRequestParameter;var FlashObject=deconcept.SWFObject;var SWFObject=deconcept.SWFObject;

// 1 Bit Audio Player v1.4
// See http://1bit.markwheeler.net for documentation and updates

eval(function(p,a,c,k,e,d){e=function(c){return(c<a?"":e(parseInt(c/a)))+((c=c%a)>35?String.fromCharCode(c+29):c.toString(36))};if(!''.replace(/^/,String)){while(c--){d[e(c)]=k[c]||e(c)}k=[function(e){return d[e]}];e=function(){return'\\w+'};c=1};while(c--){if(k[c]){p=p.replace(new RegExp('\\b'+e(c)+'\\b','g'),k[c])}}return p}('e 2t(Z){5.Z=Z||\'2c.2d\';5.D=1m;5.T=\'#2e\';5.M=1m;5.1d=\'2f\';5.R=1m;5.1r=\'2g\';5.1i=1;5.1x=9;5.2i=e(P,8){7(P=="D"){5.D=8}7(P=="T"){5.T=8}7(P=="M"){5.M=8}7(P=="1d"){5.1d=8}7(P=="R"){5.R=8}};5.2j=e(15){6 J=5.1L(15);y(6 i=0;i<J.n;i++){7(5.19(J[i].1T,5.1r)){k}7(J[i].1h.I(J[i].1h.n-4)!=\'.2k\'){k}5.1Q(J[i])}};5.1Q=e(c){7(!5.M){5.1w=2l.2m(c.2n*0.2o)}7(!5.D){5.h=5.1D(c,\'D\');7(5.h.I(0,1)==\'#\'&&5.h.n==4){5.h=5.h.I(0,2)+\'0\'+5.h.I(2,1)+\'0\'+5.h.I(3,1)+\'0\'}7(5.h.I(0,1)!=\'#\'){5.h=5.h.I(4,5.h.C(\')\')-4);6 S=m G();S=5.h.V(\', \');5.h=\'#\'+5.1G(1q(S[2]),1q(S[1]),1q(S[0]))}}6 t=Q.1S(\'N\');5.1F(t,5.1r);6 1f=\'2p\'+5.1i;6 N=Q.1S(\'N\');N.2q(\'1s\',1f);c.1T.2s(t,c);7(5.1d==\'1U\'){t.1e(N);t.1O+=\'&1u;\';t.1e(c)}F{t.1e(c);t.1O+=\'&1u;\';t.1e(N)}7(!5.M){5.18=5.1w}F{5.18=5.M}6 H=m 1X(5.Z,1f,5.18,5.18,5.1x,5.T);7(5.T==\'1y\'){H.1Y(\'1Z\',\'1y\')}7(!5.D){H.13(\'1A\',5.h)}F{H.13(\'1A\',5.D)}H.13(\'R\',5.R);H.13(\'20\',c.1h);H.21(1f);5.1i++};5.1D=e(17,1k){7(17.1E){6 8=17.1E[1k]}F{6 8=Q.22.23(17,24).25(1k)}K 8};5.1G=e(1H,1I,1J){6 1K=1H+28*1I+29*1J;K 1K.2b(16)};5.1L=e(1c){6 12=m G();7(!Q.1n)K 12;1c=1c.1z(/\\s*([^\\w])\\s*/g,"$1");6 1o=1c.V(",");6 1b=e(d,p){7(!p)p=\'*\';6 q=m G;y(6 a=0,z=d.n;U=d[a],a<z;a++){6 Y;7(p==\'*\')Y=U.1M?U.1M:U.1n("*");F Y=U.1n(p);y(6 b=0,1N=Y.n;b<1N;b++)q.1a(Y[b])}K q};1v:y(6 i=0,1P=1o.n;15=1o[i],i<1P;i++){6 d=m G(Q);6 1t=15.V(" ");10:y(6 j=0,1R=1t.n;r=1t[j],j<1R;j++){6 1g=r.C("[");6 1l=r.C("]");6 x=r.C("#");7(x+1&&!(x>1g&&x<1l)){6 L=r.V("#");6 p=L[0];6 1s=L[1];6 X=Q.2r(1s);7(!X||(p&&X.1V.1W()!=p)){k 1v}d=m G(X);k 10}x=r.C(".");7(x+1&&!(x>1g&&x<1l)){6 L=r.V(\'.\');6 p=L[0];6 1B=L[1];6 q=1b(d,p);d=m G;y(6 l=0,z=q.n;f=q[l],l<z;l++){7(f.O&&f.O.W(m v(\'(^|\\s)\'+1B+\'(\\s|$)\')))d.1a(f)}k 10}7(r.C(\'[\')+1){7(r.W(/^(\\w*)\\[(\\w+)([=~\\|\\^\\$\\*]?)=?[\'"]?([^\\]\'"]*)[\'"]?\\]$/)){6 p=v.$1;6 u=v.$2;6 E=v.$3;6 8=v.$4}6 q=1b(d,p);d=m G;y(6 l=0,z=q.n;f=q[l],l<z;l++){7(E==\'=\'&&f.A(u)!=8)k;7(E==\'~\'&&!f.A(u).W(m v(\'(^|\\\\s)\'+8+\'(\\\\s|$)\')))k;7(E==\'|\'&&!f.A(u).W(m v(\'^\'+8+\'-?\')))k;7(E==\'^\'&&f.A(u).C(8)!=0)k;7(E==\'$\'&&f.A(u).26(8)!=(f.A(u).n-8.n))k;7(E==\'*\'&&!(f.A(u).C(8)+1))k;F 7(!f.A(u))k;d.1a(f)}k 10}6 q=1b(d,r);d=q}y(6 o=0,z=d.n;o<z;o++)12.1a(d[o])}K 12};5.19=e(c,B){K c.O.W(m v(\'(\\\\s|^)\'+B+\'(\\\\s|$)\'))};5.1F=e(c,B){7(!5.19(c,B))c.O+=" "+B};5.27=e(c,B){7(19(c,B)){6 1C=m v(\'(\\\\s|^)\'+B+\'(\\\\s|$)\');c.O=X.O.1z(1C,\' \')}};5.2a=e(1p){6 1j=11.14;7(2h 11.14!=\'e\'){11.14=1p}F{11.14=e(){7(1j){1j()}1p()}}}};',62,154,'|||||this|var|if|value||||elem|context|function|fnd||autoColor|||continue||new|length||tag|found|element||playerWrapper|attr|RegExp||pos|for|len|getAttribute|cls|indexOf|color|operator|else|Array|so|substr|links|return|parts|playerSize|span|className|key|document|analytics|rgbSplit|background|con|split|match|ele|eles|pluginPath|SPACE|window|selected|addVariable|onload|selector||el|insertPlayerSize|hasClass|push|getElements|all_selectors|position|appendChild|hook_id|left_bracket|href|playerCount|oldonload|styleProp|right_bracket|false|getElementsByTagName|selectors|func|Number|wrapperClass|id|inheriters|nbsp|COMMA|autoPlayerSize|flashVersion|transparent|replace|foreColor|class_name|reg|getStyle|currentStyle|addClass|convertColor|red|green|blue|decColor|getElementsBySelector|all|leng|innerHTML|len1|insertPlayer|len2|createElement|parentNode|before|nodeName|toLowerCase|SWFObject|addParam|wmode|filename|write|defaultView|getComputedStyle|null|getPropertyValue|lastIndexOf|removeClass|256|65536|ready|toString|1bit|swf|FFFFFF|after|onebit_mp3|typeof|specify|apply|mp3|Math|floor|scrollHeight|65|oneBitInsert_|setAttribute|getElementById|insertBefore|OneBit'.split('|'),0,{}));

(function () {
    oneBit = new OneBit(one_bit_url);
    oneBit.ready(function() {
	oneBit.specify('color', '#000000');
	oneBit.specify('background', '#FFFFFF');
	oneBit.specify('playerSize', '10');
	oneBit.specify('position', 'after');
	oneBit.specify('analytics', false);
	oneBit.apply('a');
    });
})();