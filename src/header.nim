
#[
  ? enum, object, グローバル変数, 入力文字列, ライブラリ関数(errorAt) などを管理
]#

import strutils

#? 入力文字列準備
var idx* = 0
var input*: seq[char]

#? トークン
type TokenKind* = enum
    TkReserved,           # 記号
    TkIdent,              # 識別子（変数）
    TkNum,                # 整数トークン
    TkEof,                # 入力の終わりを表すトークン
    TkStr                 # 文字列リテラル

type Token* = ref object
    kind*: TokenKind            # トークンの種類
    next*: Token                # 次の入力トークン
    val*: int                   # kindがTkNumの場合，その数値
    str*: string                # トークン文字列
    at*: int                    # 入力文字配列のうち，どこを指しているか（先頭インデックス）
    stringLiteral*: seq[char]   # 文字列リテラル

var token*: Token = nil

proc errorAt*(errorMsg: string, tok: Token) = 
  # エラー表示関数（メッセージとトークンを受け取って，そのトークンの位置に値を挿入する)
  var tmp: string
  for i in input:
    tmp.add($i)
  echo tmp
  if tok == nil:
    echo " ".repeat(idx) & "^"
  else:
    echo " ".repeat(tok.at) & "^"
  quit(errorMsg)


#? 型
type TypeKind* = enum
    TyInt,
    TyPtr,
    TyArray,
    TyChar,
    TyStruct

type 
  Type* = ref object
    kind*: TypeKind       # 型の種類
    base*: Type           # TyPtrの時, 対象変数, ポインタか配列じゃなかったら，ここはnilのはず！！！
    arraySize*: int       # TyArrayで配列のサイズを計算するときに使う
    members*: Member
    align*: int           # alignment

  Member* = ref object
    next*: Member
    ty*: Type
    name*: string
    offset*: int


#? 識別子（変数， 配列)->違いはty要素で管理
type Lvar* = ref object
    name*: string                                                                     # 変数の登録チェック．  && グローバル変数はdata領域に値を確保する， アクセスする際の名前が必要
    offset*: int                # offset from RBP                                     #　スタック領域の値はこのオフセットでアクセスする．
    ty*: Type
    isLocal*: bool              # ローカル変数かグローバル変数か
    stringLiteral*: seq[char]            # 文字列リテラル seq[char]時代                  なぜ変数型の中で値を持つのか？ -> 文字列リテラルはdata領域に値を確保するから．（実行時にスタックに動的に確保するのではない）
    # stringLiteral*: string            # 文字列リテラル string時代

type LvarList* = ref object
    next*: LvarList
    lvar*: Lvar


#? ノード
type NodeKind* = enum
    NdAdd,                      # +
    NdSub,                      # -
    NdMul,                      # \*
    NdDiv,                      # /
    NdEq,                       # ==
    NdNe,                       # \!=
    NdL,                        # <
    NdLe,                       # <=

    NdNum,                      # 整数
    NdAssign,                   # = 代入式
    NdLvar,                     # 変数
    NdReturn,                   # return
    NdExprStmt,                 # 式の文
    NdIf,                       # if
    NdWhile,                    # while
    NdFor,                      # for
    NdBlock,                    # compound statement
    NdFuncall,                  # function
    NdAddr,                     # pointer &
    NdDeref,                    # pointer *
    NdNull,                     # NULL
    NdSizeof,                    # sizeof 
    NdStmtExpr,
    NdMember

type Node* = ref object
    kind*: NodeKind             # ノードの種類
    next*: Node                 # 次のノード(連結リストで管理)
    lhs*: Node                  # 左辺
    rhs*: Node                  # 右辺
    val*: int                   # kindがNdNumの場合の数値
    lvar*: Lvar                 # kindがNdLvarの時

    # kindがNdIf,NdWhileの時
    cond*: Node
    then*: Node
    els*: Node

    # kindがNdForの時
    init*: Node
    inc*: Node

    # kindがNdBlockの時
    body*: seq[Node]

    # kindがNdFuncallの時
    funcname*: string
    args*: Node

    # エラー表示用
    tok*: Token

    # 型情報
    ty*: Type

    # Struct member access
    memberName*: string
    member*: Member


#? 関数
type Function* = ref object
  next*: Function                         # 次
  name*: string                           # 名前
  params*: LvarList                       # 引数
  node*: Node                             # ノード連結リストの先頭
  locals*: LvarList                       # ローカル変数連結リストの先頭
  stackSize*: int                         # 引数+ローカル変数に用いたスタックサイズ


#? プログラム
type Program* = ref object
    globals*: LvarList                    # 連結リスト
    fns*: Function                        # 連結リスト
