---
outline: deep
---

# 切片

切片和数组看起来上很像，在实际使用时，你可能会想要使用切片，因为它相对数组来说，要更加灵活！

_你可以对数组、切片、数组指针进行切片操作！_

接下来我们演示切片的使用方式：

::: code-group

<<<@/code/release/slice.zig#basic [basic]

<<<@/code/release/slice.zig#basic_more [more]

:::

打印结果如下：

```sh
第1个元素为：1
第2个元素为：2
第3个元素为：3
slice 类型为[]i32
slice_2 类型为[]i32
```

切片的使用方式就是类似数组，不过`[]`中的是索引的边界值，遵循“左闭右开”规则。

以上我们对数组取切片，左边界值为 0，右边界值为 `len` 变量。

注意，这里说的是边界值有一个是变量（运行时可知），如果两个边界值均是编译期可知的话，编译器会直接将切片优化为数组指针。

:::info 🅿️ 提示

切片的本质：它本质是一个胖指针，包含了一个 指针类型 `[*]T` 和 长度。

同时，它的指针 `slice.ptr` 和长度 `slice.len` 均是可以操作的，但在实践中，请不要操作它们，这容易破坏切片的内部结构（除非你有把握每次都能正确的处理它们）。

:::

## 切片指针

切片本身除了具有 `len` 属性外，还具有 `ptr` 属性，这意味着我们可以通过语法 `slice.ptr` 来操作切片的指针，它是一个多项指针！

当我们对切片元素取地址（`&`）时，得到的是单项指针。

同时，切片本身还有边界检查，但是对切片指针做操作则不会有边界检查！

::: code-group

<<<@/code/release/slice.zig#pointer_slice [basic]

<<<@/code/release/slice.zig#pointer_slice_more [more]

:::

打印结果如下：

```sh
slice 类型为[]i32
slice.ptr 类型为[*]i32
slice 的索引 0 取地址，得到指针类型为*i32
```

## 哨兵切片（标记终止切片）

语法 `[:x]T` 是一个切片，它具有运行时已知的长度，并且还保证由该长度索引的元素的标记值。该类型不保证在此之前不存在哨兵元素，哨兵终止的切片允许元素访问 len 索引。

哨兵切片也可以使用切片语法 `data[start..end :x]` 的变体来创建，其中 data 是多项指针、数组或切片，x 是哨兵值。

哨兵切片认定哨兵位置处的元素是哨兵值，如果不是这种情况，则会触发安全保护中的未定义问题。

::: code-group

<<<@/code/release/slice.zig#terminated_slice [basic]

<<<@/code/release/slice.zig#terminated_slice_more [more]

:::

打印结果如下：

```sh
str_slice类型：[:0]const u8
slice类型：[:0]u8
```
