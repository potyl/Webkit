console.log(snum + '/' + smax + ' incpos:  ' + incpos + " number: " + number)


function _fini() {
    var last_slide = (snum == smax - 1) ? true : false;
    var last_subslide = ( !incrementals[snum] || incpos >= incrementals[snum].length ) ? true : false;
    var ret = (last_slide && last_subslide) ? true : false ;
console.log("last_slide: " + last_slide + "; last_subslide: " + last_subslide + "; fini: " + ret);
console.log("end? " +  (  (snum == smax - 1) && ( !incrementals[snum] || incpos >= incrementals[snum].length ) ));
    return ret;
}

    console.log("last_slide: " + last_slide + "; last_subslide: " + last_subslide + "; fini: " + ret);


function _nextSlide() {

console.log("Fini ? " + ( snum  == smax -1 && ( !incrementals[snum] || incpos >= incrementals[snum].length ) ) ? 'Oui' : 'Non' );

console.log("ratio " + (snum == smax - 1 ? 'Y' : 'N') + "; incr ? " + (!incrementals[snum] || incpos >= incrementals[snum].length ? 'Oui' : 'Non') );


console.log("number ? " + ( number != undef ? 'Y' : 'N') + " ratio " + (snum == smax - 1 ? 'Y' : 'N') + " incr ? " + (!incrementals[snum] || incpos >= incrementals[snum].length ? 'Oui' : 'Non') );


	if(number != undef) {
		go(number);
	} else if (!incrementals[snum] || incpos >= incrementals[snum].length) {
		go(1);
	} else {
		subgo(1);
	}

    return true;
}
