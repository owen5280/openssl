#! /usr/bin/env perl
# Copyright 2010-2020 The OpenSSL Project Authors. All Rights Reserved.
#
# Licensed under the Apache License 2.0 (the "License").  You may not use
# this file except in compliance with the License.  You can obtain a copy
# in the file LICENSE in the source distribution or at
# https://www.openssl.org/source/license.html

#
# ====================================================================
# Written by Andy Polyakov, @dot-asm, initially for use in the OpenSSL
# project. The module is, however, dual licensed under OpenSSL and
# CRYPTOGAMS licenses depending on where you obtain it. For further
# details see https://github.com/dot-asm/cryptogams/.
# ====================================================================

# This module doesn't present direct interest for OpenSSL, because it
# doesn't provide better performance for longer keys, at least not on
# in-order-execution cores. While 512-bit RSA sign operations can be
# 65% faster in 64-bit mode, 1024-bit ones are only 15% faster, and
# 4096-bit ones are up to 15% slower. In 32-bit mode it varies from
# 16% improvement for 512-bit RSA sign to -33% for 4096-bit RSA
# verify:-( All comparisons are against bn_mul_mont-free assembler.
# The module might be of interest to embedded system developers, as
# the code is smaller than 1KB, yet offers >3x improvement on MIPS64
# and 75-30% [less for longer keys] on MIPS32 over compiler-generated
# code.

######################################################################
# There is a number of MIPS ABI in use, O32 and N32/64 are most
# widely used. Then there is a new contender: NUBI. It appears that if
# one picks the latter, it's possible to arrange code in ABI neutral
# manner. Therefore let's stick to NUBI register layout:
#
($zero,$at,$t0,$t1,$t2)=map("\$$_",(0..2,24,25));
($a0,$a1,$a2,$a3,$a4,$a5,$a6,$a7)=map("\$$_",(4..11));
($s0,$s1,$s2,$s3,$s4,$s5,$s6,$s7,$s8,$s9,$s10,$s11)=map("\$$_",(12..23));
($gp,$tp,$sp,$fp,$ra)=map("\$$_",(3,28..31));
#
# The return value is placed in $a0. Following coding rules facilitate
# interoperability:
#
# - never ever touch $tp, "thread pointer", former $gp;
# - copy return value to $t0, former $v0 [or to $a0 if you're adapting
#   old code];
# - on O32 populate $a4-$a7 with 'lw $aN,4*N($sp)' if necessary;
#
# For reference here is register layout for N32/64 MIPS ABIs:
#
# ($zero,$at,$v0,$v1)=map("\$$_",(0..3));
# ($a0,$a1,$a2,$a3,$a4,$a5,$a6,$a7)=map("\$$_",(4..11));
# ($t0,$t1,$t2,$t3,$t8,$t9)=map("\$$_",(12..15,24,25));
# ($s0,$s1,$s2,$s3,$s4,$s5,$s6,$s7)=map("\$$_",(16..23));
# ($gp,$sp,$fp,$ra)=map("\$$_",(28..31));

# $output is the last argument if it looks like a file (it has an extension)
# $flavour is the first argument if it doesn't look like a file
$output = $#ARGV >= 0 && $ARGV[$#ARGV] =~ m|\.\w+$| ? pop : undef;
# supported flavours are o32,n32,64,nubi32,nubi64, default is o32
$flavour = $#ARGV >= 0 && $ARGV[0] !~ m|\.| ? shift : "o32";

if ($flavour =~ /64|n32/i) {
	$PTR_ADD="daddu";	# incidentally works even on n32
	$PTR_SUB="dsubu";	# incidentally works even on n32
	$REG_S="sd";
	$REG_L="ld";
	$SZREG=8;
} else {
	$PTR_ADD="addu";
	$PTR_SUB="subu";
	$REG_S="sw";
	$REG_L="lw";
	$SZREG=4;
}
$SAVED_REGS_MASK = ($flavour =~ /nubi/i) ? 0x00fff000 : 0x00ff0000;
#
# <https://github.com/dot-asm>
#
######################################################################

$output and open STDOUT,">$output";

if ($flavour =~ /64|n32/i) {
	$LD="ld";
	$ST="sd";
	$MULTU="dmultu";
	$ADDU="daddu";
	$SUBU="dsubu";
	$BNSZ=8;
} else {
	$LD="lw";
	$ST="sw";
	$MULTU="multu";
	$ADDU="addu";
	$SUBU="subu";
	$BNSZ=4;
}

# int bn_mul_mont(
$rp=$a0;	# BN_ULONG *rp,
$ap=$a1;	# const BN_ULONG *ap,
$bp=$a2;	# const BN_ULONG *bp,
$np=$a3;	# const BN_ULONG *np,
$n0=$a4;	# const BN_ULONG *n0,
$num=$a5;	# int num);

$lo0=$a6;
$hi0=$a7;
$lo1=$t1;
$hi1=$t2;
$aj=$s0;
$bi=$s1;
$nj=$s2;
$tp=$s3;
$alo=$s4;
$ahi=$s5;
$nlo=$s6;
$nhi=$s7;
$tj=$s8;
$i=$s9;
$j=$s10;
$m1=$s11;

$FRAMESIZE=14;

$code=<<___;
#include "mips_arch.h"

.text

.set	noat
.set	noreorder

.align	5
.globl	bn_mul_mont
.ent	bn_mul_mont
bn_mul_mont:
___
$code.=<<___ if ($flavour =~ /o32/i);
	lw	$n0,16($sp)
	lw	$num,20($sp)
___
$code.=<<___;
	slt	$at,$num,4
	bnez	$at,1f
	li	$t0,0
	slt	$at,$num,17	# on in-order CPU
	bnez	$at,bn_mul_mont_internal
	nop
1:	jr	$ra
	li	$a0,0
.end	bn_mul_mont

.align	5
.ent	bn_mul_mont_internal
bn_mul_mont_internal:
	.frame	$fp,$FRAMESIZE*$SZREG,$ra
	.mask	0x40000000|$SAVED_REGS_MASK,-$SZREG
	$PTR_SUB $sp,$FRAMESIZE*$SZREG
	$REG_S	$fp,($FRAMESIZE-1)*$SZREG($sp)
	$REG_S	$s11,($FRAMESIZE-2)*$SZREG($sp)
	$REG_S	$s10,($FRAMESIZE-3)*$SZREG($sp)
	$REG_S	$s9,($FRAMESIZE-4)*$SZREG($sp)
	$REG_S	$s8,($FRAMESIZE-5)*$SZREG($sp)
	$REG_S	$s7,($FRAMESIZE-6)*$SZREG($sp)
	$REG_S	$s6,($FRAMESIZE-7)*$SZREG($sp)
	$REG_S	$s5,($FRAMESIZE-8)*$SZREG($sp)
	$REG_S	$s4,($FRAMESIZE-9)*$SZREG($sp)
___
$code.=<<___ if ($flavour =~ /nubi/i);
	$REG_S	$s3,($FRAMESIZE-10)*$SZREG($sp)
	$REG_S	$s2,($FRAMESIZE-11)*$SZREG($sp)
	$REG_S	$s1,($FRAMESIZE-12)*$SZREG($sp)
	$REG_S	$s0,($FRAMESIZE-13)*$SZREG($sp)
___
$code.=<<___;
	move	$fp,$sp

	.set	reorder
	$LD	$n0,0($n0)
	$LD	$bi,0($bp)	# bp[0]
	$LD	$aj,0($ap)	# ap[0]
	$LD	$nj,0($np)	# np[0]

	$PTR_SUB $sp,2*$BNSZ	# place for two extra words
	sll	$num,`log($BNSZ)/log(2)`
	li	$at,-4096
	$PTR_SUB $sp,$num
	and	$sp,$at

	$MULTU	($aj,$bi)
	$LD	$ahi,$BNSZ($ap)
	$LD	$nhi,$BNSZ($np)
	mflo	($lo0,$aj,$bi)
	mfhi	($hi0,$aj,$bi)
	$MULTU	($lo0,$n0)
	mflo	($m1,$lo0,$n0)

	$MULTU	($ahi,$bi)
	mflo	($alo,$ahi,$bi)
	mfhi	($ahi,$ahi,$bi)

	$MULTU	($nj,$m1)
	mflo	($lo1,$nj,$m1)
	mfhi	($hi1,$nj,$m1)
	$MULTU	($nhi,$m1)
	$ADDU	$lo1,$lo0
	sltu	$at,$lo1,$lo0
	$ADDU	$hi1,$at
	mflo	($nlo,$nhi,$m1)
	mfhi	($nhi,$nhi,$m1)

	move	$tp,$sp
	li	$j,2*$BNSZ
.align	4
.L1st:
	.set	noreorder
	$PTR_ADD $aj,$ap,$j
	$PTR_ADD $nj,$np,$j
	$LD	$aj,($aj)
	$LD	$nj,($nj)

	$MULTU	($aj,$bi)
	$ADDU	$lo0,$alo,$hi0
	$ADDU	$lo1,$nlo,$hi1
	sltu	$at,$lo0,$hi0
	sltu	$t0,$lo1,$hi1
	$ADDU	$hi0,$ahi,$at
	$ADDU	$hi1,$nhi,$t0
	mflo	($alo,$aj,$bi)
	mfhi	($ahi,$aj,$bi)

	$ADDU	$lo1,$lo0
	sltu	$at,$lo1,$lo0
	$MULTU	($nj,$m1)
	$ADDU	$hi1,$at
	addu	$j,$BNSZ
	$ST	$lo1,($tp)
	sltu	$t0,$j,$num
	mflo	($nlo,$nj,$m1)
	mfhi	($nhi,$nj,$m1)

	bnez	$t0,.L1st
	$PTR_ADD $tp,$BNSZ
	.set	reorder

	$ADDU	$lo0,$alo,$hi0
	sltu	$at,$lo0,$hi0
	$ADDU	$hi0,$ahi,$at

	$ADDU	$lo1,$nlo,$hi1
	sltu	$t0,$lo1,$hi1
	$ADDU	$hi1,$nhi,$t0
	$ADDU	$lo1,$lo0
	sltu	$at,$lo1,$lo0
	$ADDU	$hi1,$at

	$ST	$lo1,($tp)

	$ADDU	$hi1,$hi0
	sltu	$at,$hi1,$hi0
	$ST	$hi1,$BNSZ($tp)
	$ST	$at,2*$BNSZ($tp)

	li	$i,$BNSZ
.align	4
.Louter:
	$PTR_ADD $bi,$bp,$i
	$LD	$bi,($bi)
	$LD	$aj,($ap)
	$LD	$ahi,$BNSZ($ap)
	$LD	$tj,($sp)

	$MULTU	($aj,$bi)
	$LD	$nj,($np)
	$LD	$nhi,$BNSZ($np)
	mflo	($lo0,$aj,$bi)
	mfhi	($hi0,$aj,$bi)
	$ADDU	$lo0,$tj
	$MULTU	($lo0,$n0)
	sltu	$at,$lo0,$tj
	$ADDU	$hi0,$at
	mflo	($m1,$lo0,$n0)

	$MULTU	($ahi,$bi)
	mflo	($alo,$ahi,$bi)
	mfhi	($ahi,$ahi,$bi)

	$MULTU	($nj,$m1)
	mflo	($lo1,$nj,$m1)
	mfhi	($hi1,$nj,$m1)

	$MULTU	($nhi,$m1)
	$ADDU	$lo1,$lo0
	sltu	$at,$lo1,$lo0
	$ADDU	$hi1,$at
	mflo	($nlo,$nhi,$m1)
	mfhi	($nhi,$nhi,$m1)

	move	$tp,$sp
	li	$j,2*$BNSZ
	$LD	$tj,$BNSZ($tp)
.align	4
.Linner:
	.set	noreorder
	$PTR_ADD $aj,$ap,$j
	$PTR_ADD $nj,$np,$j
	$LD	$aj,($aj)
	$LD	$nj,($nj)

	$MULTU	($aj,$bi)
	$ADDU	$lo0,$alo,$hi0
	$ADDU	$lo1,$nlo,$hi1
	sltu	$at,$lo0,$hi0
	sltu	$t0,$lo1,$hi1
	$ADDU	$hi0,$ahi,$at
	$ADDU	$hi1,$nhi,$t0
	mflo	($alo,$aj,$bi)
	mfhi	($ahi,$aj,$bi)

	$ADDU	$lo0,$tj
	addu	$j,$BNSZ
	$MULTU	($nj,$m1)
	sltu	$at,$lo0,$tj
	$ADDU	$lo1,$lo0
	$ADDU	$hi0,$at
	sltu	$t0,$lo1,$lo0
	$LD	$tj,2*$BNSZ($tp)
	$ADDU	$hi1,$t0
	sltu	$at,$j,$num
	mflo	($nlo,$nj,$m1)
	mfhi	($nhi,$nj,$m1)
	$ST	$lo1,($tp)
	bnez	$at,.Linner
	$PTR_ADD $tp,$BNSZ
	.set	reorder

	$ADDU	$lo0,$alo,$hi0
	sltu	$at,$lo0,$hi0
	$ADDU	$hi0,$ahi,$at
	$ADDU	$lo0,$tj
	sltu	$t0,$lo0,$tj
	$ADDU	$hi0,$t0

	$LD	$tj,2*$BNSZ($tp)
	$ADDU	$lo1,$nlo,$hi1
	sltu	$at,$lo1,$hi1
	$ADDU	$hi1,$nhi,$at
	$ADDU	$lo1,$lo0
	sltu	$t0,$lo1,$lo0
	$ADDU	$hi1,$t0
	$ST	$lo1,($tp)

	$ADDU	$lo1,$hi1,$hi0
	sltu	$hi1,$lo1,$hi0
	$ADDU	$lo1,$tj
	sltu	$at,$lo1,$tj
	$ADDU	$hi1,$at
	$ST	$lo1,$BNSZ($tp)
	$ST	$hi1,2*$BNSZ($tp)

	addu	$i,$BNSZ
	sltu	$t0,$i,$num
	bnez	$t0,.Louter

	.set	noreorder
	$PTR_ADD $tj,$sp,$num	# &tp[num]
	move	$tp,$sp
	move	$ap,$sp
	li	$hi0,0		# clear borrow bit

.align	4
.Lsub:	$LD	$lo0,($tp)
	$LD	$lo1,($np)
	$PTR_ADD $tp,$BNSZ
	$PTR_ADD $np,$BNSZ
	$SUBU	$lo1,$lo0,$lo1	# tp[i]-np[i]
	sgtu	$at,$lo1,$lo0
	$SUBU	$lo0,$lo1,$hi0
	sgtu	$hi0,$lo0,$lo1
	$ST	$lo0,($rp)
	or	$hi0,$at
	sltu	$at,$tp,$tj
	bnez	$at,.Lsub
	$PTR_ADD $rp,$BNSZ

	$SUBU	$hi0,$hi1,$hi0	# handle upmost overflow bit
	move	$tp,$sp
	$PTR_SUB $rp,$num	# restore rp
	not	$hi1,$hi0

.Lcopy:	$LD	$nj,($tp)	# conditional move
	$LD	$aj,($rp)
	$ST	$zero,($tp)
	$PTR_ADD $tp,$BNSZ
	and	$nj,$hi0
	and	$aj,$hi1
	or	$aj,$nj
	sltu	$at,$tp,$tj
	$ST	$aj,($rp)
	bnez	$at,.Lcopy
	$PTR_ADD $rp,$BNSZ

	li	$a0,1
	li	$t0,1

	.set	noreorder
	move	$sp,$fp
	$REG_L	$fp,($FRAMESIZE-1)*$SZREG($sp)
	$REG_L	$s11,($FRAMESIZE-2)*$SZREG($sp)
	$REG_L	$s10,($FRAMESIZE-3)*$SZREG($sp)
	$REG_L	$s9,($FRAMESIZE-4)*$SZREG($sp)
	$REG_L	$s8,($FRAMESIZE-5)*$SZREG($sp)
	$REG_L	$s7,($FRAMESIZE-6)*$SZREG($sp)
	$REG_L	$s6,($FRAMESIZE-7)*$SZREG($sp)
	$REG_L	$s5,($FRAMESIZE-8)*$SZREG($sp)
	$REG_L	$s4,($FRAMESIZE-9)*$SZREG($sp)
___
$code.=<<___ if ($flavour =~ /nubi/i);
	$REG_L	$s3,($FRAMESIZE-10)*$SZREG($sp)
	$REG_L	$s2,($FRAMESIZE-11)*$SZREG($sp)
	$REG_L	$s1,($FRAMESIZE-12)*$SZREG($sp)
	$REG_L	$s0,($FRAMESIZE-13)*$SZREG($sp)
___
$code.=<<___;
	jr	$ra
	$PTR_ADD $sp,$FRAMESIZE*$SZREG
.end	bn_mul_mont_internal
.rdata
.asciiz	"Montgomery Multiplication for MIPS, CRYPTOGAMS by <https://github.com/dot-asm>"
___

$code =~ s/\`([^\`]*)\`/eval $1/gem;

print $code;
close STDOUT or die "error closing STDOUT: $!";
