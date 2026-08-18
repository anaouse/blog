---
title: Markdown 语法与公式测试
created_at: 2026-08-18T16:00:00+08:00
---

这是一篇用于测试的文章，覆盖常见的 Markdown 语法和公式渲染。

## 标题层级

### 三级标题

#### 四级标题

## 文字样式

普通文字，**加粗**，*斜体*，~~删除线~~，`行内代码`，[链接](https://sleeponthegrass.com)。

## 列表

无序列表：

- 项目一
- 项目二
  - 嵌套项

有序列表：

1. 第一项
2. 第二项

## 引用

> 这是引用块。
> 保持极简。

## 表格

| 名称 | 说明 |
| --- | --- |
| react-markdown | 渲染 Markdown |
| remark-gfm | GFM 扩展 |
| rehype-katex | 公式渲染 |

## 代码块

```go
func main() {
	fmt.Println("hello")
}
```

## 行内公式

行内公式 $E = mc^2$ 直接写在句子里。

## 块级公式

$$
\int_0^\infty x^2 dx = \frac{1}{3}x^3 \Big|_0^\infty
$$

$$
e^{i\pi} + 1 = 0
$$
