.intel_syntax noprefix
.global _start


.bss
bf_mem_sz == 256 # bytes
file_buffer_sz = 1024 # bytes
file_buff: .space file_buffer_sz  # load bf code file
bf_mem: .space bf_mem_sz          # bf interpreter memory

.data
argcError:
  .asciz "Provide exactly one file\n"
arcError_len = . - [argcError]
nl = . - 2 # addr of null-terminated newline from above
           # saves 1-2 bytes >:)

.text

_exitProgram:
  mov rax, 60   # exit syscall
  mov rdi, 0    # exit code
  syscall
  ret

_exitWithError:
  mov rdi, rax  # pass error value as rax
  mov rax, 60   # exit syscall
  syscall
  ret

_badArgc:
  mov rax, 1
  mov rdi, 1
  lea rsi, [argcError]
  mov rdx, arcError_len
  syscall # print error
  mov rax, 1
  call _exitWithError

_lenz:
  push rax    # &str
  mov rdx, 0  # store length here
nonNullCounter:
  inc rax
  inc rdx
  mov cl, [rax]
  cmp cl, 0
  jne nonNullCounter
  pop rax
  ret

_printz:
  mov rax, rsi # pass string handle as rsi
  call _lenz   # set len in rdx
  mov rax, 1
  mov rdi, 1
  syscall
  ret

_printzln:
  call _printz
  mov rax, 1
  mov rdi, 1
  lea rsi, nl
  mov rdx, 1
  syscall
  ret


_continue_loop:
  mov r12, [rsp] # peek stack for innermost loop begin
_next_instruction:
  inc r12
  jmp _interpret
_interpret:
  # match loop
  cmp byte ptr [r12], '+
  je _bf_inc
  cmp byte ptr [r12], '-
  je _bf_dec
  cmp byte ptr [r12], '>
  je _bf_right
  cmp byte ptr [r12], '<
  je _bf_left
  cmp byte ptr [r12], '.
  je _bf_print
  cmp byte ptr [r12], ',
  je _bf_read
  cmp byte ptr [r12], '[
  je _bf_loop_start
  cmp byte ptr [r12], ']
  je _bf_loop_end
  # stop on non-printing character
  cmp byte ptr [r12], 0x20 # control char below <SPACE>
  jl _end_interpret
  cmp byte ptr [r12], 0x7F # <DEL> or 0b1xxxxxx
  jge _end_interpret

  # ignore all other characters
  jmp _next_instruction

_end_interpret:
  ret


_bf_inc:            # +
  inc byte ptr [bf_mem+r14]
  jmp _next_instruction

_bf_dec:            # -
  dec byte ptr [bf_mem+r14]
  jmp _next_instruction

_bf_right:          # >
  inc r14
  cmp r14, 256  # past the end
  jne _next_instruction
  mov r14, 0    # wrap around
  jmp _next_instruction

_bf_left:           # <
  dec r14
  cmp r14, 256  # past the end
  jl _next_instruction
  mov r14, 255  # wrap around
  jmp _next_instruction

_bf_print:          # .
  mov rax, 1
  mov rdi, 1
  lea rsi, [bf_mem+r14]
  mov rdx, 1
  syscall
  jmp _next_instruction

_bf_read:           # ,
  mov rax, 0
  mov rdi, 0
  mov rdx, 1
  lea rsi, [bf_mem+r14]
  syscall
  jmp _next_instruction

_bf_loop_start:     # [
  push r12 # save loop start
  jmp _next_instruction

_bf_loop_end:       # ]
  cmp byte ptr [bf_mem+r14], 0 # end loop condition
  jne _continue_loop
  # loop now ends
  add rsp, 8 # remove pointer to start of loop
  jmp _next_instruction



_start:
  pop rax           # argc
  cmp rax, 2
  jne _badArgc
  
  pop rax           # argv[0] ./main
  mov rax, [rsp]    # argv[1] .bf file (peek)
  
  #mov rsi, rax   # debug
  #call _printzln # debug

  # open file
  mov rdi, rax  # move filename
  mov rax, 2
  mov rsi, 0    # readonly
  mov rdx, 0
  syscall
  push rax # close later

  # load (read) file : first 1k
  mov rdi, rax # move file descriptor
  mov rax, 0
  mov rdx, file_buffer_sz 
  lea rsi, file_buff
  syscall # file contents at [rsi]
  #call _printzln # debug prints file contents
  ## TODO: file error handling

  # init
  mov r14, 0 # BF Mem index
  mov r12, rsi # BF Inst. pointer
  call _interpret

  # close file
  pop rdi
  mov rax, 3
  syscall

exit:
  call _exitProgram


# Register Assignment:
# bit : reg : use
# ====================
# 8+b : r14 : BF Memory Index
# 64b : r13 : Swap register
# 64b : r12 : BF Instruction pointer
# MISC
# 64b : r15 : stack pointer before file buffer
