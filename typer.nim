#[
  ? ノードごとにそれぞれ値を持っている． その値が何の型なのか決めている.

  ? 値
  * kind, lhs, rhs
  * kind, lhs
  * val
  * lvar
]#

import header

proc newType(kind: TypeKind): Type =
  var ty = new Type
  ty.kind = kind
  return ty

#? int型生成
proc intType*(): Type =
  return newType(TyInt)

#? char型生成
proc charType*(): Type =
  return newType(TyChar)

#? Ptr型生成(baseとなる型を受け取る)
proc pointerType*(base: Type): Type =
  var ty = newType(TyPtr)
  ty.base = base
  return ty

#? Array型生成(baseとなる型とサイズを受け取る)
proc arrayType*(base: Type, size: int): Type =
  var ty = newType(TyArray)
  ty.base = base
  ty.arraySize = size
  return ty


#? スタックで確保するバイト数
proc sizeType*(ty: Type): int =                         # これよく書き間違える．．
  case ty.kind:
  of TyInt, TyPtr:
    return 8
  of TyChar:
    return 1
  else:
    assert(ty.kind == TyArray)                            # 現状，intとptr以外はarray
    return sizeType(ty.base) * ty.arraySize

#? nodeの持つ全ての要素nodeに訪れる．（再帰ループ)
proc visit(node: Node) =
  if node == nil:                                       # 再帰の返り値
    return

  visit(node.lhs)
  visit(node.rhs)
  visit(node.cond)
  visit(node.then)
  visit(node.els)
  visit(node.init)
  visit(node.inc)
  
  for n in node.body:                                             # 配列の場合
    if n != nil:
      visit(n)

  var n = node.args                                               # 連結リストの場合
  while n != nil:
    visit(n)
    n = n.next

  #? 型付け
  case node.kind
  of NdNum, NdMul, NdDiv, NdEq, NdNe, NdL, NdLe, NdFuncall:       # 現状はこれらのノードはint型
    node.ty = intType()
    return
  of NdAdd:
    if node.rhs.ty.base != nil:                                   #! 右辺がポインタ.....3 + ptrみたいな式はあり得るOK -> 入れ替えて確認
      var tmp = node.lhs
      node.lhs = node.rhs
      node.rhs = tmp
    if node.rhs.ty.base != nil:                                   #! 右辺がポインタ.....ptr + ptr という式はない
      errorAt("invalid pointer arithmetic operands", node.tok)
    node.ty = node.lhs.ty                                         #! 右辺値がTyPtrだったらlhsとrhsを交換してるから自動的に，　右辺値がポインタなら右辺値の型，　右辺値が数値なら左辺値の型を入れる
                                                                  #! 加算はlhsとrhsが入れ替わっても問題ない(依存してない)
    return
  of NdSub:
    if node.rhs.ty.base != nil:                                   #! 右辺値がポインタ．．．．．．．3 - ptr みたいな式は存在しない
      errorAt("invalid pointer arithmetic operands", node.tok)
    node.ty = node.lhs.ty                                         #! 評価結果の型は，左辺の型に依存
    return
  of NdAssign:
    node.ty = node.lhs.ty                                         #! 代入は「代入する値の型」に依存する！！！！
    return
  of NdAddr:
    if node.lhs.ty.kind == TyArray:                               # 配列のポインタ
      node.ty = pointerType(node.lhs.ty.base)                     #! 配列は既にbaseを持っている．のでbaseをbaseとしたポインタ型を返す
    else:
      node.ty = pointerType(node.lhs.ty)                          #! node.lhs.ty(代入する値の型）をbase(依存)としたポインタ型を返す
    return
  of NdDeref:
    if node.lhs.ty.base == nil:                                   # お前はデリファレンスできねえ！
      errorAt("invalid pointer dereference", node.tok)
    node.ty = node.lhs.ty.base                                    #! このノードは，baseの型に依存する
    return
  of NdLvar:
    node.ty = node.lvar.ty                                        #! 変数ノードは，変数の型に依存する！！
    return                                                        #! ノードごとにそれぞれ値を持っている．その値が何の型なのか決めているのか
  of NdSizeof:
    node.kind = NdNum
    node.ty = intType()
    node.val = sizeType(node.lhs.ty)
    node.lhs = nil
  else:
    discard

#? annotate AST nodes with types
proc addType*(prog: Program) =                          # ただの2重ループ(関数 -> ノード)
  var fn = prog .fns
  while fn != nil:
    var node = fn.node
    while node != nil:
      visit(node)
      node = node.next
    fn = fn.next