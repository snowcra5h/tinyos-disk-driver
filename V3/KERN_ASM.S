					xdef	_restart
					xdef	_load_cpu_context
				
					xdef	_exit,_sys_exit
					xref	_do_exit
					
					xdef	_create_process,_sys_create_process
					xref	_do_create_process
					
					xdef	_write,_sys_write
					xref	_do_write
						
					xdef	_read,_sys_read
					xref	_do_read
					
					xdef	_get_pid,_sys_get_pid
					xref	_do_get_pid
					
					xdef	_yield,_sys_yield
					xref	_do_yield

					xdef	_waitfstatus,_sys_waitfstatus
					xref	_do_waitfstatus

					xdef	_disk_operation,_sys_disk_operation
					xref	_do_disk_operation
					xdef	_floppy_isr
					xref	_do_floppy_isr

					xdef	_vbl_isr
					xref	_do_vbl_isr
					xdef	_addr_exception_isr
					xref	_do_addr_exception_isr
					xdef	_exception_isr
					xref	_do_exception_isr
					xref	_init
					xdef	_read_SR,_write_SR
					xdef	_await_interrupt
					xdef	_timer_A_isr
					xref	_do_timer_A_isr
					xdef	_ikbd_isr
					xref	_do_ikbd_isr
					xref	_proc,_curr_proc
					xdef	_clear_screen
					xdef	_scroll
					xref	_resched_needed
					xref	_schedule
					xref	_panic

;OS_ROM_START		equ		$FC0030
;OS_ROM_END			equ		$FF0000

OS_RAM_TOP			equ		$000800	
MEM_CONFIG_REG		equ		$FF8001
VIDEO_BASE_REG		equ		$FF8201
VIDEO_SYNC_REG		equ		$FF820A
VIDEO_PAL0_REG		equ		$FF8240
VIDEO_REZ_REG   	equ		$FF8260

RAM_4M				equ		$0A
VIDEO_BASE			equ		$3F8000
MONO				equ		$02

CPU_CONTEXT_SIZE	equ		70
PROCESS_ENTRY_SIZE	equ		102

start:				move.w	#$2700,sr
					reset
					movea.l	#OS_RAM_TOP,sp
					move.b	#RAM_4M,MEM_CONFIG_REG
													; FD related
;					move.w	#$190,$FF8606			; clear the fifo
;					move.w	#$90,$FF8606			; and leave in the write state
					move.l	#VIDEO_BASE,d0
					lsr.l	#8,d0
					movea.l	#VIDEO_BASE_REG,a0
					movep.w	d0,0(a0)
					clr.b	VIDEO_SYNC_REG
					move.w	#1,VIDEO_PAL0_REG
					move.b	#MONO,VIDEO_REZ_REG
					jsr		_init

_restart:			jmp		start

; note: if we attempt to restart in user mode, a privilege violation will
;       cause the CPU to vector to "_restart" in supervisor mode

					
_exception_isr:		jsr		_do_exception_isr		; doesn't return
					jsr		_panic

_addr_exception_isr:
					jsr		_do_addr_exception_isr	; doesn't return
					jsr		_panic


_vbl_isr:			movem.l	d0-2/a0-2,-(sp)
					jsr		_do_vbl_isr
					movem.l	(sp)+,d0-2/a0-2
					jsr		pre_return
					rte
					
pre_return:			cmpi.w	#$2000,4(sp)			; check if S bit was set (xxSx xxxx xxxx xxxx)
					bhs.s	out2					; ... if invoked from kernel, just return (nested ISR)
					move.l	a0,-(sp)
					ori.w	#$0700,sr				; mask IRQs for remainder of return to user
					movea.l	_resched_needed,a0
					tst.w	(a0)					; check if reschedule needed
					beq.s	out1					; ... if not, just return to original process
					cmpi.w	#2,(a0)
					bne.s	after_pc_adjust
					subi.l	#2,10(sp)				; if trap blocked process, it will need to be re-started
after_pc_adjust:	movea.l	_curr_proc,a0			; switch to next process
					move.l	d0,-(sp)
					move.w	(a0),d0
					mulu.w	#PROCESS_ENTRY_SIZE,d0
					movea.l	_proc,a0
					lea		(a0,d0.w),a0
					move.l	(sp)+,d0
					jsr		_store_cpu_context
					jsr		_schedule				; doesn't return
out1:				movea.l	(sp)+,a0
out2:				rts

_floppy_isr:		movem.l d0-2/a0-2,-(sp)
					jsr		_do_floppy_isr
					movem.l	(sp)+,d0-2/a0-2
					jsr		pre_return
					rte

_timer_A_isr:		movem.l	d0-2/a0-2,-(sp)
					jsr		_do_timer_A_isr
					movem.l	(sp)+,d0-2/a0-2
					jsr		pre_return
					rte
					
_ikbd_isr:			movem.l	d0-2/a0-2,-(sp)
					jsr		_do_ikbd_isr
					movem.l	(sp)+,d0-2/a0-2
					jsr		pre_return
					rte

_create_process:	link	a6,#0
					move.w	10(a6),-(sp)
					move.w	8(a6),-(sp)
					trap	#2
					addq.l	#4,sp
					unlk	a6
					rts

_sys_create_process:
					movem.l	d0-2/a0-2,-(sp)
					move.l	usp,a0
					move.w	2(a0),-(sp)
					move.w	(a0),-(sp)
					jsr		_do_create_process
					addq.l	#4,sp
					movem.l	(sp)+,d0-2/a0-2
					jsr		pre_return
					rte
					
_exit:				trap	#1						; no parameter
					
_sys_exit:			jsr		_do_exit				; doesn't return
					jsr		_panic

_write:				link	a6,#0
					move.w	12(a6),-(sp)
					move.l	8(a6),-(sp)
					trap	#3
					unlk	a6
					rts
					
_waitfstatus:		trap	#9
					rts

_sys_waitfstatus:	move.l	usp,a0
					jsr		_do_waitfstatus
					jsr		pre_return
					rte

_sys_write:			move.l	usp,a0
					move.w	4(a0),-(sp)
					move.l	(a0),-(sp)
					jsr		_do_write
					addq.l	#6,sp
					jsr		pre_return
					rte
					
_read:				link	a6,#0
					move.w	12(a6),-(sp)
					move.l	8(a6),-(sp)
					trap	#4						; returns with output in d0.w
					unlk	a6
					rts
					
_sys_read:			;movem.l	d0-2/a0-2,-(sp)		; [TO DO] simplify reg save/restore for exceptions & traps
					move.l	usp,a0
					move.w	4(a0),-(sp)
					move.l	(a0),-(sp)
					jsr		_do_read				; returns with output in d0.w
					addq.l	#6,sp
					;movem.l	(sp)+,d0-2/a0-2
					jsr		pre_return
					rte

_disk_operation:	link 	a6,#0					; create new stack frame
					move.l	8(a6),-(sp)				; Push pointer to disk_io_request_t struct pointer onto stack
					trap	#6						; returns with output in d0.w
					unlk	a6						; Restore previous stack frame
					rts

_sys_disk_operation:
					move.l	usp,a0					; move user stack pointer to a0
					move.l	(a0),-(sp)				; Push pointer to disk_io_request_t struct pointer onto stack
					jsr		_do_disk_operation		; Call c function to perform operation
					addq.l	#4,sp					; cleanup stack
					jsr		pre_return				; 
					rte								; return from exception

_get_pid:			trap	#5						; returns with output in d0.w
					rts
					
_sys_get_pid:		jsr		_do_get_pid				; returns with output in d0.w
					jsr		pre_return
					rte

_yield:				trap	#7
					rts
					
_sys_yield:			jsr		_do_yield				; doesn't return
					jsr		pre_return
					jsr		_panic
					
_read_SR:			move.w	sr,d0
					rts

_write_SR:			move.w	4(sp),sr
					rts

_await_interrupt:	stop	#$2200
					rts

					
base	equ		64									; offset from SP, not A6

_clear_screen:		movem.l	d0-7/a0-6,-(sp)
					lea		zeros,a0
					movem.l	(a0)+,d1-7/a1-6
					movea.l	base(sp),a0
					adda.l	#32000,a0
					move.w	#614,d0
fill_loop:			movem.l	d1-7/a1-6,-(a0)
					dbra	d0,fill_loop
					movem.l	d1-5,-(a0)
					movem.l	(sp)+,d0-7/a0-6
					rts

zeros:				ds.l	13

_scroll:			movem.l	d3-7/a3-5,-(sp)
					movea.l	#VIDEO_BASE,a1
					movea.l	#VIDEO_BASE+640,a0
					move.w	#783,d0
					move.l	#40,d1
scroll_most:		movem.l	(a0)+,d2-d7/a2-5
					movem.l	d2-7/a2-5,(a1)
					adda.l	d1,a1
					dbra	d0,scroll_most
					movea.l	#VIDEO_BASE+32000,a1
					lea		zeros,a0
					movem.l	(a0),d2-7/a2-5
					moveq.w	#15,d0
clear_rest:			movem.l	d2-7/a2-5,-(a1)
					dbra	d0,clear_rest
					movem.l	(sp)+,d3-7/a3-5
					rts

					
; END PART OF SWITCH TO PROCESS:

_load_cpu_context:	movea.l	4(sp),a0				; passed Context struct start addr
					movea.l	#OS_RAM_TOP,sp
					move.l	(a0)+,-(sp)
					move.w	(a0)+,-(sp)
					movea.l	(a0)+,a1
					move.l	a1,usp
					movem.l	(a0)+,d0-7/a1-6
					movea.l	(a0),a0
					rte

; PART OF SWITCH FROM PROCESS - CALLED FROM ISR WITH STACK (TOP-DOWN) AS:
;
;	saved PC
;	saved SR
;	return address (back to ISR)
;	saved A0
;	return address (back to pre_return)
;
;... AND MUST BE CALLED WITH CPU D0-7/A1-6 EXACTLY AS-WAS AT START OF ISR
;... AND A0 pointing to Context struct start addr
;... AND can't be called by address/bus error ISR (extra data on stack)

_store_cpu_context:	adda.l	#CPU_CONTEXT_SIZE,a0
					move.l	4(sp),-(a0)
					movem.l	d0-7/a1-6,-(a0)
					move.l	usp,a1
					move.l	a1,-(a0)
					move.w	12(sp),-(a0)
					move.l	14(sp),-(a0)
					rts
