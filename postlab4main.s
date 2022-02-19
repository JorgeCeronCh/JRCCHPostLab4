/*	
    Archivo:		prelab4main.S
    Dispositivo:	PIC16F887
    Autor:		Jorge Cerón 20288
    Compilador:		pic-as (v2.30), MPLABX V6.00

    Programa:		2 Contadores hexadecimales de 7 segmentos
			Contador binario de 4 bits incremento/decremento con interrupciones
    Hardware:		LEDs en puerto A y contador de 7 segmentos en puerto C y D

    Creado:			17/02/22
    Última modificación:	17/02/22	
*/
PROCESSOR 16F887
#include <xc.inc>

; configuracion 1
  CONFIG  FOSC = INTRC_NOCLKOUT // Oscillador Interno sin salidas
  CONFIG  WDTE = OFF            // WDT (Watchdog Timer Enable bit) disabled (reinicio repetitivo del pic)
  CONFIG  PWRTE = ON            // PWRT enabled (Power-up Timer Enable bit) (espera de 72 ms al iniciar)
  CONFIG  MCLRE = OFF           // El pin de MCL se utiliza como I/O
  CONFIG  CP = OFF              // Sin proteccion de codigo
  CONFIG  CPD = OFF             // Sin proteccion de datos
  
  CONFIG  BOREN = OFF           // Sin reinicio cunado el voltaje de alimentación baja de 4V
  CONFIG  IESO = OFF            // Reinicio sin cambio de reloj de interno a externo
  CONFIG  FCMEN = OFF           // Cambio de reloj externo a interno en caso de fallo
  CONFIG  LVP = ON              // programación en bajo voltaje permitida

; configuracion  2
  CONFIG  WRT = OFF             // Protección de autoescritura por el programa desactivada
  CONFIG  BOR4V = BOR40V        // Reinicio abajo de 4V, (BOR21V = 2.1V)
  
UP	EQU 0			// PIN 0 para incrementar
DOWN	EQU 1			// PIN 1 para decrementar

PSECT udata_bank0
    CONT1:	    DS 1
    CONTS1:	    DS 1
    CONTS2:	    DS 1
    
;----------------MACROS--------------- Macro para reiniciar el valor del Timer0
RESETTIMER0 MACRO
    BANKSEL TMR0	// Direccionamiento al banco 00
    MOVLW   217		// Cargar literal en el registro W
    MOVWF   TMR0	// Configuración completa para que tenga 20ms de retardo
    BCF	    T0IF	// Se limpia la bandera de interrupción
    
    ENDM	
; Status para interrupciones
PSECT udata_shr			// Variables globales en memoria compartida
    WTEMP:	    DS 1	// 1 byte
    STATUSTEMP:	    DS 1	// 1 byte
     
PSECT resVect, class=CODE, abs, delta=2
;----------------vector reset----------------
ORG 00h				// Posición 0000h para el reset
resVect:
    PAGESEL	main		//Cambio de página
    GOTO	main

PSECT intVect, class=CODE, abs, delta=2 
;----------------vector interrupcion---------------
ORG 04h				// Posición 0004h para las interrupciones
PUSH:				// PC a pila
    MOVWF   WTEMP		// Se mueve W a la variable WTEMP
    SWAPF   STATUS, W		// Swap de nibbles del status y se almacena en W
    MOVWF   STATUSTEMP		// Se mueve W a la variable STATUSTEMP
ISR:				// Rutina de interrupción
    BTFSC   RBIF		// Analiza la bandera de cambio del PORTB si esta encendida (si no lo está salta una linea)
    CALL    INTERRUPIOCB	// Se llama la rutina de interrupción del puerto B
    
    BTFSC   T0IF		// Analiza la bandera del TMR0 si esta encendida (si no lo está salta una linea)
    CALL    INTERRUPTMR0	// Se llama la rutina de interrupción del TMR0
    
    BANKSEL PORTA
POP:				// Intruccion movida de la pila al PC
    SWAPF   STATUSTEMP, W	// Swap de nibbles de la variable STATUSTEMP y se almacena en W
    MOVWF   STATUS		// Se mueve W a status
    SWAPF   WTEMP, F		// Swap de nibbles de la variable WTEMP y se almacena en WTEMP 
    SWAPF   WTEMP, W		// Swap de nibbles de la variable WTEMP y se almacena en w
    RETFIE
    
INTERRUPTMR0:
    RESETTIMER0			// Tiempo configurado para 20mS
    INCF    CONT1		// Incremento en 1 la variable CONT1
    MOVF    CONT1, W		// Se mueve CONT1 a W
    SUBLW   50			// Se resta 50 a W (cuando W llegue a 50, será 1 segundo)
    BTFSC   ZERO		// Si la operación de la resta es cero, se activa la bandera zero (si no lo está se salta una línea)
    CALL    INCPORTC		// Si se activa la bandera zero, se llama la rutina incremento en puerto C
    
    RETURN
INCPORTC:
    CLRF    CONT1		// Se limpia la variable CONT1
    INCF    CONTS1		// Se incrementa en 1 la variable CONTS1
    MOVF    CONTS1, W		// Se mueve CONTS1 a W
    CALL    TABLA		// Se llama a la subrutina Tabla
    MOVWF   PORTC		// Se mueve lo que de la Tabla al display del puerto C
    
    MOVF    CONTS1, W		// Se mueve CONTS1 a W
    SUBLW   10			// Se resta 10 a W (cuando W llegue a 10, los segundos en unidades pasaran a ser decimas)
    BTFSC   ZERO		// Si la operación de la resta es cero, se activa la bandera zero (si no lo está se salta una línea)
    CALL    INCPORTD		// Si se activa la bandera zero, se llama la rutina incremento en puerto D
   
    RETURN

INCPORTD:
    CLRF    CONTS1		// Se limpia la variable CONTS1
    MOVLW   00111111B		// Mover la literal a W
    MOVWF   PORTC		// Asignar valor de W (0) al display
    
    INCF    CONTS2		// Incremento en 1 a la variable CONTS2
    MOVF    CONTS2, W		// Se meuve CONTS2 a W
    SUBLW   6			// Se resta 6 a W (cuando W llegue a 6, se cumple el minuto)
    BTFSC   ZERO		// Si la operación de la resta es cero, se activa la bandera zero (si no lo está se salta una línea)
    CLRF    CONTS2		// Si se activa la bandera zero, se limpia CONTS2
    MOVF    CONTS2, W		// Si no es cero, se mueve CONTS2 a W
    CALL    TABLA		// Se llama a la subrutina Tabla
    MOVWF   PORTD		// Se mueve lo que de la Tabla al display del puerto D
    
    RETURN  
    
INTERRUPIOCB:
    BANKSEL PORTA
    BTFSS   PORTB, UP		// Analiza RB0 si no esta presionado (si está presionado salta una linea)
    INCF    PORTA		// Incremento en 1 puerto A
    BTFSS   PORTB, DOWN		// Analiza RB1 si no esta presionado (si está presionado salta una linea)
    DECF    PORTA		// Disminución en 1 puerto A
    BCF	    RBIF		// Se limpia la bandera de cambio de estado del PORTB
    
    RETURN

PSECT code, abs, delta=2   
;----------------configuracion----------------
ORG 100h
main:
    CALL    CONFIGIO	    // Se llama la rutina configuración de entradas y salidas
    CALL    CONFIGRELOJ	    // Se llama la rutina configuración del reloj
    CALL    CONFIGTIMER0    // Se llama la rutina configuración del Timer0
    CALL    CONFIGINTERRUP  // Se llama la rutina configuración de interrupciones
    CALL    CONFIIOCB	    // Se llama la rutina configuración de interrupcion en PORTB
    BANKSEL PORTA
    
loop:
    GOTO    loop	    // Regresa a revisar
    
CONFIGIO:
    BANKSEL ANSEL	    // Direccionar al banco 11
    CLRF    ANSEL	    // I/O digitales
    CLRF    ANSELH	    // I/O digitales
    
    BANKSEL TRISA	    // Direccionar al banco 01
    BSF	    TRISB, UP	    // RB0 como entrada
    BSF	    TRISB, DOWN	    // RB1 como entrada
    BCF	    TRISA, 0	    // RA0 como salida
    BCF	    TRISA, 1	    // RA1 como salida
    BCF	    TRISA, 2	    // RA2 como salida
    BCF	    TRISA, 3	    // RA3 como salida
    CLRF    TRISC
    CLRF    TRISD
    
    BCF	    OPTION_REG, 7   // RBPU habilita las resistencias pull-up 
    BSF	    WPUB, UP	    // Habilita el registro de pull-up en RB0 
    BSF	    WPUB, DOWN	    // Habilita el registro de pull-up en RB1
    
    BANKSEL PORTA	    // Direccionar al banco 00
    CLRF    PORTA	    // Se limpia PORTA
    CLRF    PORTB	    // Se limpia PORTB
    CLRF    PORTC
    CLRF    PORTD
    MOVLW   00111111B	    // Mover la literal a W
    MOVWF   PORTC	    // Asignar valor de W (0) al display
    MOVLW   00111111B	    // Mover la literal a W
    MOVWF   PORTD	    // Asignar valor de W (0) al display
    CLRF    CONT1	    // Se limpia la variable CONT1
    CLRF    CONTS1	    // Se limpia la variable CONTS1
    CLRF    CONTS2	    // Se limpia la variable CONTS2

    RETURN
    
CONFIGRELOJ:
    BANKSEL OSCCON	    // Direccionamiento al banco 01
    BSF	    OSCCON, 0	    // SCS en 1, se configura a reloj interno
    BSF	    OSCCON, 6	    // bit 6 en 1
    BCF	    OSCCON, 5	    // bit 5 en 0
    BSF	    OSCCON, 4	    // bit 4 en 1
    // Frecuencia interna del oscilador configurada a 2MHz
    RETURN  

CONFIGTIMER0:
    BANKSEL OPTION_REG		// Direccionamiento al banco 01
    BCF	    OPTION_REG, 5	// TMR0 como temporizador
    BCF	    OPTION_REG, 3	// Prescaler a TMR0
    BSF	    OPTION_REG, 2	// bit 2 en 1
    BSF	    OPTION_REG, 1	// bit 1 en 1
    BSF	    OPTION_REG, 0	// bit 0 en 1
    // Prescaler en 256
    // Sabiendo que N = 256 - (T*Fosc)/(4*Ps) -> 256-(0.02*2*10^6)/(4*256) = 216.93 (217 aprox)
    BANKSEL TMR0	// Direccionamiento al banco 00
    MOVLW   217		// Cargar literal en el registro W
    MOVWF   TMR0	// Configuración completa para que tenga 20ms de retardo
    BCF	    T0IF	// Se limpia la bandera de interrupción
    
    RETURN
    
CONFIGINTERRUP:
    BANKSEL INTCON
    BSF	    GIE		    // Habilita interrupciones globales
    BSF	    RBIE	    // Habilita interrupciones de cambio de estado del PORTB
    BCF	    RBIF	    // Se limpia la banderda de cambio del puerto B
    
    BSF	    T0IE	    // Habilita interrupción TMR0
    BCF	    T0IF	    // Se limpia de una vez la bandera de TMR0
    
    RETURN

CONFIIOCB:		    // Interrupt on-change PORTB register
    BANKSEL TRISA
    BSF	    IOCB, UP	    // Interrupción control de cambio en el valor de B
    BSF	    IOCB, DOWN	    // Interrupción control de cambio en el valor de B
    
    BANKSEL PORTA
    MOVF    PORTB, W	    // Termina la condición de mismatch, compara con W
    BCF	    RBIF	    // Se limpia la bandera de cambio de PORTB
    RETURN

ORG 200h
TABLA:
    CLRF    PCLATH	// Se limpia el registro PCLATH
    BSF	    PCLATH, 1	
    ANDLW   0x0F	// Solo deja pasar valores menores a 16
    ADDWF   PCL		// Se añade al PC el caracter en ASCII del contador
    RETLW   00111111B	// Return que devuelve una literal a la vez 0 en el contador de 7 segmentos
    RETLW   00000110B	// Return que devuelve una literal a la vez 1 en el contador de 7 segmentos
    RETLW   01011011B	// Return que devuelve una literal a la vez 2 en el contador de 7 segmentos
    RETLW   01001111B	// Return que devuelve una literal a la vez 3 en el contador de 7 segmentos
    RETLW   01100110B	// Return que devuelve una literal a la vez 4 en el contador de 7 segmentos
    RETLW   01101101B	// Return que devuelve una literal a la vez 5 en el contador de 7 segmentos
    RETLW   01111101B	// Return que devuelve una literal a la vez 6 en el contador de 7 segmentos
    RETLW   00000111B	// Return que devuelve una literal a la vez 7 en el contador de 7 segmentos
    RETLW   01111111B	// Return que devuelve una literal a la vez 8 en el contador de 7 segmentos
    RETLW   01101111B	// Return que devuelve una literal a la vez 9 en el contador de 7 segmentos
    RETLW   01110111B	// Return que devuelve una literal a la vez A en el contador de 7 segmentos
    RETLW   01111100B	// Return que devuelve una literal a la vez b en el contador de 7 segmentos
    RETLW   00111001B	// Return que devuelve una literal a la vez C en el contador de 7 segmentos
    RETLW   01011110B	// Return que devuelve una literal a la vez d en el contador de 7 segmentos
    RETLW   01111001B	// Return que devuelve una literal a la vez E en el contador de 7 segmentos
    RETLW   01110001B	// Return que devuelve una literal a la vez F en el contador de 7 segmentos
END








