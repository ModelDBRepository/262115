TITLE multiple GABAa receptors

COMMENT
-----------------------------------------------------------------------------
Mechanism for handling multiple presynaptic entries to the same compartment;
up to 1000 synapses can be handled using a different pointer that must be set
for each presynaptic variable using addlink.  Optimization algorithm from
Lytton, W.W., Neural Computation, in press, 1996.  This mechanism allows
considerable acceleration of the simulation time if many receptors of the same
type must be simulated in the same compartment.

This file was configured for GABAa receptors.  The mechanism was a first-order
kinetic model with pulse of transmitter (see Destexhe, A., Mainen, Z. and
Sejnowski, T.J.  Neural Computation, 6: 14-18, 1994).

Parameters were obtained from fitting the model to whole-cell recorded GABAa
postsynaptic currents (Otis et al, J. Physiol.  463: 391-407, 1993).  The fit
was performed using a simplex algorithm using short pulses of transmitter (0.5
mM during 0.3 ms).

-----------------------------------------------------------------------------
EXAMPLE OF HOW TO USE:

create POST,PRE[10]		// create compartments
objectvar c			// create an object
c = new multiGABAa()		// create multiple GABAa kinetic synapses
POST c.loc(0.5)			// localize synapse on postsyn compartment
c.gmax = 0.001			// assign max conductance of each syn (mu S)
c.allocate(10)			// allocate space for 10 presyn variables
for i=0,9 { 			// link presynaptic variables
   c.addlink(&PRE[i].v)
}  
-----------------------------------------------------------------------------
WARNINGS:

  - only ok for synaptic mechanisms where all weights are equal
    (see Lytton paper for implementation of different weights)


  Alain Destexhe, Laval University, 1995

-----------------------------------------------------------------------------
ENDCOMMENT

: defines maximal number of possible links to presynaptic variables
: this number should correpond to the number of pointers pre00, pre01, ...
: defined in the NEURON block

DEFINE MAXSYNGABAA 260
VERBATIM
static int MAXSYNGABAA = 260;
ENDVERBATIM

INDEPENDENT {t FROM 0 TO 1 WITH 1 (ms)}

NEURON {
	POINT_PROCESS multiGABAa
	NONSPECIFIC_CURRENT i
	RANGE Ron, Roff, ri, nsyn, non, g, gmax
	GLOBAL Cmax, Cdur, Alpha, Beta, Erev, Prethresh, Deadtime, Rinf, Rtau
}

UNITS {
	(nA) = (nanoamp)
	(mV) = (millivolt)
	(umho) = (micromho)
	(mM) = (milli/liter)
}

PARAMETER {
	dt		(ms)

	Cmax	= 0.5	(mM)		: max transmitter concentration
	Cdur	= 0.3	(ms)		: transmitter duration (rising phase)
	Alpha	= 20	(/ms mM)	: forward (binding) rate
	Beta	= 0.162	(/ms)		: backward (unbinding) rate
	Erev	= -80	(mV)		: reversal potential
	gmax		(umho)		: maximum conductance of each synapse

	Prethresh = 0 			: voltage level nec for release
	Deadtime = 1	(ms)		: mimimum time between release events
}


ASSIGNED {
	on[MAXSYNGABAA]			: state of each synapse
	TL[MAXSYNGABAA]	(ms)		: time since last event for each synapse
	ri[MAXSYNGABAA]			: state variable of each synapse
	lastrelease[MAXSYNGABAA] (ms)	: last release for each synapse
	Ron				: sum of all "on" synapses
	Roff				: sum of all "off" synapses
	nsyn				: number of synapses
	non				: number of synapses on

	Rinf				: steady state channels open
	Rtau		(ms)		: time constant of channel binding

	v		(mV)		: postsynaptic voltage
	i 		(nA)		: total current = g*(v - Erev)
	g 		(umho)		: total conductance

	trel		(ms)		: temp var
	ptr_array_gabaa			: pointer array
}

INITIAL { LOCAL j
	FROM j=0 TO nsyn-1 {
		on[j] = 0
		TL[j] = -9e9
		lastrelease[j] = -9e9
		ri[j] = 0
	}
	Ron = 0
	Roff = 0
	non = 0

	Rinf = Cmax*Alpha / (Cmax*Alpha + Beta)
	Rtau = 1 / ((Alpha * Cmax) + Beta)
}

BREAKPOINT {
   if(gmax > 0) {
	SOLVE release
	g = gmax * (Ron+Roff)
	i = g*(v - Erev)
   } else {
	i = 0
   }
}

PROCEDURE release() { LOCAL q,j

  FROM j=0 TO nsyn-1 {	: update Ron, Roff, non for each synapse

    trel = ((t - lastrelease[j]) - Cdur)	: time since last release ended

    if (trel > Deadtime) {			: ready for another release?
				
	if (presynaptic(j) > Prethresh) {	: spike occured?
	  on[j] = 1			: start new release
	  non = non + 1
	  lastrelease[j] = t		: memorize release time
	  ri[j] = ri[j] * exptable( - Beta * (t-TL[j]))
					: evaluate state variable
	  TL[j] = t			: memorize last event
	  Ron = Ron + ri[j]		: increase Ron
	  Roff = Roff - ri[j]		: decrease Roff
	  if(Roff < 1e-9) { Roff = 0 }	: prevent roundoff errors
	}
						
    } else if (trel < 0) {			: still releasing?

		: do nothing
	
    } else if (on[j] > 0) {			: end of release ?
	on[j] = 0			: stop release
	non = non - 1
	ri[j] = Rinf + (ri[j]-Rinf) * exptable(- (t-TL[j]) / Rtau)
					: evaluate state variable
	TL[j] = t			: memorize last event
	Ron = Ron - ri[j]		: decrease Ron
	Roff = Roff + ri[j]		: increase Roff
	if(Ron < 1e-9) { Ron = 0 }	: prevent roundoff errors
    }

  }


  if(Roff > 0) {			: update Roff
     Roff = Roff * exptable(- Beta * dt)
     if(Roff < 1e-9) { Roff = 0 }	: prevent roundoff errors
  }

  if(non > 0) {				: update Ron
    q = non * Rinf
    Ron = q + (Ron - q) * exptable(- dt / Rtau) 
  }

}


FUNCTION exptable(x) { 
	TABLE  FROM -25 TO 25 WITH 10000

	if ((x > -25) && (x < 25)) {
		exptable = exp(x)
	} else {
		exptable = 0.
	}
}



:FUNCTION exptable(x) { 
:	TABLE  FROM -10 TO 10 WITH 10000
:
:	if ((x > -10) && (x < 10)) {
:		exptable = exp(x)
:	} else {
:		exptable = 0.
:	}
:}



:FUNCTION exptable(x) {
:	if(x > -50) {
:		exptable = exp(x)
:	} else {
:		exptable = 0.
:	}
:}



:-------------------------------------------------------------------
:  Procedures for pointer arrays in nmodl 
:  create a pointer array and link its pointers to variables passed
:  from hoc (adapted from Mike Hines)
:-------------------------------------------------------------------


VERBATIM
#define ppgabaa ((double***)(&(ptr_array_gabaa)))
extern double* hoc_pgetarg();
ENDVERBATIM


:
: Procedure to allocate space for n pointers
:
PROCEDURE allocate(n) {
  VERBATIM
	if (*ppgabaa) {
	   free(*ppgabaa);
	}
	*ppgabaa = ((double**) hoc_Ecalloc((int)_ln, sizeof(double *))), hoc_malchk();
  ENDVERBATIM
}

:
: procedure to get the value of a presynaptic variable
: index is the number of the presynaptic var
:
FUNCTION presynaptic(index) {
  VERBATIM
	if(_lindex >= nsyn) {
	   printf("Warning: attempt to use pointer outside range\n");
	   printf(" trying to use pointer number %d\n",(int)_lindex);
	   printf(" but number of defined pointers was nsyn=%d.\n",(int) nsyn);
	}
	_lpresynaptic = *((*ppgabaa)[(int)_lindex]);
  ENDVERBATIM
}


:
: procedure to add a new presynaptic variable
: the address of the variable is passed as argument (from hoc)
: a new pointer is then linked to that variable
:
PROCEDURE addlink() {
  VERBATIM
	if(++nsyn > MAXSYNGABAA) {
	  printf("Exceeding maximum of allowed links MAXSYNGABAA=%d\n",MAXSYNGABAA);
	  printf("  edit the nmodl code to increase the maximum allowed.\n");
	  exit(-1);
	}
	(*ppgabaa)[(int)(nsyn-1)] = hoc_pgetarg(1);
  ENDVERBATIM
}
