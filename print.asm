	section	.text
	global	_print

_print:
	pushad

	xor	eax,			eax
	and [number],		eax
	and [number + 4],	eax
	and [number + 8],	eax
	and [number + 12],	eax
	and [width],		eax
	and [fmt],			eax

	mov	eax,	[esp + 32 + 12] ; input
	mov ecx,	[esp + 32 + 8]  ; format
	mov	ebx,	[esp + 32 + 4]  ; out_buf

	call 	read_hex

	call 	read_format
	call 	optimize_fmt

	xor		esi,	esi ; length of out_buf
	call 	write_number

	xor ecx,	ecx
	and [ebx + esi],	ecx

	popad
	ret



read_hex:
	push 	eax
	push 	ecx

	mov		cl,	[eax]
	cmp		cl,	'-'
	jne 	positive
	push 	1
	inc 	eax
	jmp 	convert
positive:
	push 	0

convert:

	mov		cl,	[eax]
	test	cl,	cl
	jz 		stop_converting

	inc		eax

	mov		edi,	[number + 12]
	mov		esi,	[number + 8]
	shl		edi,	4
	shr		esi,	28
	or		edi,	esi
	mov		[number + 12],	edi

	mov		edi,	[number + 8]
	mov		esi,	[number + 4]
	shl		edi,	4
	shr		esi,	28
	or		edi,	esi
	mov		[number + 8],	edi

	mov		edi,	[number + 4]
	mov		esi,	[number]
	shl		edi,	4
	shr		esi,	28
	or		edi,	esi
	mov		[number + 4],	edi

	mov 	edi,	[number]
	shl		edi,	4
	mov		[number],	edi

	cmp		cl,	'9'
	jg		small
	sub		cl, '0'
	jmp		next_bit
small:
	cmp		cl,	'Z'
	jg 		big
	sub 	cl,	55
	jmp		next_bit
big:
	sub		cl,	87

next_bit:
	or		[number],	cl
	xor		cl,	cl
	adc		[number + 4],	cl
	adc		[number + 8],	cl
	adc		[number + 12],	cl
	jmp		convert

stop_converting:
	pop 	ecx
	test 	ecx,	ecx
	jz 		negated
	call	big_not
	call 	big_inc

negated:
	pop 	ecx
	pop 	eax
	ret



big_not:
	xor		edx,	edx
	not 	edx
	xor 	[number],	edx
	xor 	[number + 4],	edx
	xor 	[number + 8],	edx
	xor 	[number + 12],	edx
	ret

big_inc:
	mov	dl,	1
	add	[number],	dl
	xor dl,	dl
	adc	[number + 4],	dl
	adc	[number + 8],	dl
	adc	[number + 12],	dl
	ret

big_div_modulo:
	xor		edx,	edx
	mov		eax,	[number + 12]
	div		ecx
	mov		[number + 12],	eax
	mov		eax, 	[number + 8]
	div 	ecx
	mov 	[number + 8],	eax
	mov 	eax,	[number + 4]
	div 	ecx
	mov		[number + 4],	eax
	mov		eax,	[number]
	div 	ecx
	mov 	[number],	eax
	ret



read_format:
	push 	eax
	push 	ebx
	push 	edi

	xor 	ebx,	ebx

parse_all:
	mov 	al,	[ecx + ebx]
	inc 	ebx
	test	al,	al
	jz 		format_parsed

	cmp 	al,	'-'
	jne 	check_signed
	mov 	edi,	[left]
	or		[fmt],	edi
	jmp 	parse_all
check_signed:
	cmp 	al,	'+'
	jne 	check_spaced
	mov 	edi,	[signed]
	or 		[fmt],	edi
	jmp 	parse_all
check_spaced:
	cmp		al, ' '
	jne 	check_width
	mov 	edi,	[spaced]
	or 		[fmt],	edi
	jmp 	parse_all
check_width:
	cmp 	al, '0'
	jl 		parse_all
	cmp 	al,	'9'
	jg 		parse_all
	call 	parse_width
	jmp 	parse_all

format_parsed:
	pop 	edi
	pop 	ebx
	pop 	eax
	ret



parse_width:
	xor		edx,	edx
	mov 	dl,	al
	mov 	esi,	10
	xor 	eax,	eax
	cmp 	dl,	'0'
	jne 	unzero
	mov 	edi,	[zeros]
	or 		[fmt],	edi
	jmp 	parse_width_value
unzero:
	mov		eax,	edx
	sub		eax,	'0'
parse_width_value:
	xor 	edx,	edx
	mov 	dl,	[ecx + ebx]
	cmp 	dl, '0'
	jl 		set_width
	cmp 	dl,	'9'
	jg 		set_width

	mov		edi,	edx
	mul 	esi
	sub 	edi,	'0'
	add 	eax,	edi
	inc 	ebx
	jmp 	parse_width_value

set_width:
	mov		[width],	eax
	ret



optimize_fmt:
	push 	eax

	mov eax,	[fmt]
	and eax,	[left]
	jz 	optimize_signed
	mov eax,	[fmt]
	mov edi,	[zeros]
	and	eax,	edi
	jz 	optimize_signed
	not edi
	and	[fmt],	edi

optimize_signed:
	mov eax,	[fmt]
	and	eax,	[signed]
	jz 	optimized
	mov eax,	[fmt]
	mov edi,	[spaced]
	and	eax,	edi
	jz 	optimized
	not edi
	and	[fmt],	edi

optimized:
	pop eax
	ret



write_number:
	push 	eax

	mov	ecx,	10
	xor	edi,	edi ; count of digits

	mov		eax,	[number + 12]
	shr 	eax,	31
	and		eax,	1
	jz		next_digit_to_stack
	call	big_not
	call	big_inc
	inc 	esi

next_digit_to_stack:

	call 	big_div_modulo

	inc		edi
	add		edx,	'0'
	push 	edx

	; check isZero
	mov 	eax,	[number]
	test	eax,	eax
	jnz		next_digit_to_stack
	mov 	eax,	[number + 4]
	test	eax,	eax
	jnz		next_digit_to_stack
	mov 	eax,	[number + 8]
	test	eax,	eax
	jnz		next_digit_to_stack
	mov 	eax,	[number + 12]
	test	eax,	eax
	jnz		next_digit_to_stack

	call 	apply_prefix_format

next_digit_to_out:
	test	edi,	edi
	jz 		return
	dec		edi
	pop 	ecx
	mov 	[ebx + esi],	ecx
	inc 	esi
	jmp 	next_digit_to_out

return:
	call 	apply_postfix_format
	pop 	eax
	ret



apply_prefix_format:
	push 	ebp
	xor 	ebp,	ebp
	
	cmp		esi,	1
	jne		apply_signed
	mov		ebp,	'-'
	jmp		apply_width

apply_signed:
	mov		edx,	[fmt]
	and		edx,	[signed]
	jz 		apply_spaced
	or		esi,	1
	mov 	ebp,	'+'
	jmp		apply_width
apply_spaced:
	mov		edx,	[fmt]
	and 	edx,	[spaced]
	jz 		apply_width
	or		esi,	1
	mov 	ebp,	' '

apply_width:
	mov 	edx,	[width]
	sub 	edx,	esi
	sub 	edx,	edi

	push 	edi
	xor 	esi,	esi

	test 	edx,	edx
	jle 	without_indent

	mov 	edi,	[fmt]
	and 	edi,	[left]
	jnz 	without_indent

	mov		edi,	[fmt]
	and 	edi,	[zeros]
	jnz		write_zeros

	mov 	ecx,	edx
	mov 	al,	' '
	call 	write_ecx_times
	jmp 	without_indent 	

write_zeros:
	call 	write_sign
	mov 	ecx,	edx
	mov 	al,	'0'
	call 	write_ecx_times
	jmp 	prefix_applied

without_indent:
	call 	write_sign
prefix_applied:
	pop 	edi
	pop 	ebp
	ret



; al - character to write
write_ecx_times:
	mov 	[ebx + esi],	al
	inc 	esi
	dec 	ecx
	test 	ecx,	ecx
	jnz 	write_ecx_times
	ret


; ebp - sign to write. 0, if no sign
write_sign:
	test 	ebp,	ebp
	jz 		sign_written
	mov		[ebx + esi],	ebp
	inc 	esi
sign_written:
	ret



apply_postfix_format:
	mov 	edx,	[fmt]
	and 	edx,	[left]
	jz 		postfix_applied

	mov		ecx,	[width]
	sub 	ecx,	esi

	test 	ecx,	ecx
	jle		postfix_applied

	mov 	al,	' '
	call 	write_ecx_times

postfix_applied:
	ret



	section	.data
number:	dd 0, 0, 0, 0
width: dd 0
fmt: dd 0
left: dd 1
signed: dd 2
zeros: dd 4
spaced: dd 8
