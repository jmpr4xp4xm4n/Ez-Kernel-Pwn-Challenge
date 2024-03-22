The challenge creates a character device that can be interacted from userspace
using ioctl calls. There are two available options in the device. First one is
to allocate a chunk in heap and storing that pointer as a global variable and
stores the size as an unsigned char at the first byte of the allocated chunk. Second
is an edit functionality to put data into the chunk we allocated with the first
option. The alloc option can be only called once and the edit option can be called
twice.

The bug is in the alloc function where the size of the chunk is taken from a pointer
to userspace without copying it to kernel. So there is no guarantee the value at
that pointer will remain same during the execution of the alloc function. If userspace
calls the ioctl and triggers the alloc and at the same time, in a seperate thread
if the size is modified, and this modfication is done after kernel has allocated
the chunk but before it wrote the value to the chunk's first byte, userspace
can then use the edit function to overflow from the chunk to next chunk since the size
used for edit is different from size used for allocation.

Since the chunk is in kmalloc-64, we have a limited number of structures that we can
use as a target. user_key_payload is a good target since we can use it to leak kernel
address as well as get rip control. First we need to bypass the freelist randomization.
To do this also, we will use user_key_payload. We spray user_key_payload until
the page is almost full. Now we use the alloc option to allocate a chunk in the same
page while triggering the bug so the size is now a larger value than the one used
for allocation. Next we spray more user_key_payload to completely fill the page.

In this stage, we will have our chunk in between a lot of user_key_paylods. Since the
device doesn't provide any functionality to read data, we will use keyctl's
KEYCTL_READ operation to get our leaks. Our goal with the overflow is to overwrite
the size field of the user_key_payload next to our chunk so that we can use
keyctl read on that user_key_payload to leak pointers from user_key_payloads next to
that. Since the order in which the sprayed keys got allocated is random, we need a
way to know which key is the one we will be overwriting. To do this, we do keyctl
read on all the keys and see their return value. The one with the size that we faked
will be our traget.

To get leaks, we need to call KEYCTL_UPDATE on all other keys so that their rcu field
gets filled with a function pointer. After this, we do keyctl read on the target key
so that it leaks the pointers from key right next to it. This way we get kernel base.

Our next goal is to get rip control. We can again make use of the rcu pointers that
are written to the key when we call UPDATE on it. These rcu pointers are called after
a specific amount of time. So if we are to overwrite it once the update writes it on
the key and before it gets called, we get rip control.

To do this, we use the edit option one more time. We call keyctl update on the target,
then immediately do edit to overwrite the rcu pointer. Now when rcu pointer is called,
we get rip control.

Since the device uses userspace memory directly, SMAP is disabled. Because of this,
we can just do a stack pivot to userspace and execute a ROP chain to get root and read
the flag.
