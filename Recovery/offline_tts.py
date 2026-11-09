import ctypes,sys,runpy
lib=ctypes.CDLL('libseccomp.so.2')
lib.seccomp_init.argtypes=[ctypes.c_uint32];lib.seccomp_init.restype=ctypes.c_void_p
lib.seccomp_syscall_resolve_name.argtypes=[ctypes.c_char_p];lib.seccomp_syscall_resolve_name.restype=ctypes.c_int
lib.seccomp_rule_add.argtypes=[ctypes.c_void_p,ctypes.c_uint32,ctypes.c_int,ctypes.c_uint]
lib.seccomp_load.argtypes=[ctypes.c_void_p];lib.seccomp_release.argtypes=[ctypes.c_void_p]
c=lib.seccomp_init(0x7fff0000);assert c
for name in [b'socket',b'connect',b'sendto',b'sendmsg',b'sendmmsg']:
 number=lib.seccomp_syscall_resolve_name(name);assert number>=0 and lib.seccomp_rule_add(c,0x00050000|13,number,0)==0
assert lib.seccomp_load(c)==0;lib.seccomp_release(c)
import socket
try:socket.socket(socket.AF_INET,socket.SOCK_STREAM);raise RuntimeError('Networking enabled')
except PermissionError:pass
print('OFFLINE_TTS: all network calls prohibited by kernel',flush=True)
sys.argv=sys.argv[1:];runpy.run_path(sys.argv[0],run_name='__main__')
