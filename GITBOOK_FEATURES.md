# GitBook Features & Markdown Extensions

This document outlines the GitBook-specific features and markdown extensions you can use in your documentation.

## GitBook-Specific Markdown

### Hints & Callouts

```markdown
{% hint style="info" %}
This is an info hint box.
{% endhint %}

{% hint style="warning" %}
This is a warning hint box.
{% endhint %}

{% hint style="danger" %}
This is a danger/error hint box.
{% endhint %}

{% hint style="success" %}
This is a success hint box.
{% endhint %}
```

### Tabs

```markdown
{% tabs %}
{% tab title="JavaScript" %}
```javascript
console.log('Hello World');
```
{% endtab %}

{% tab title="Python" %}
```python
print('Hello World')
```
{% endtab %}
{% endtabs %}
```

### Code Groups

```markdown
{% code title="package.json" %}
```json
{
  "name": "my-project",
  "version": "1.0.0"
}
```
{% endcode %}
```

### Expandable Sections

```markdown
<details>
<summary>Click to expand</summary>

Content that will be hidden by default.

</details>
```

### File Trees

```markdown
```
project/
├── src/
│   ├── components/
│   └── utils/
├── tests/
└── README.md
```
```

## Standard Markdown Features

### Tables

```markdown
| Feature | Supported | Notes |
|---------|-----------|-------|
| Tables | ✅ | Full support |
| Links | ✅ | Internal and external |
| Images | ✅ | Drag and drop in GitBook |
```

### Task Lists

```markdown
- [x] Completed task
- [ ] Pending task
- [ ] Another pending task
```

### Blockquotes

```markdown
> This is a blockquote
> 
> With multiple lines
```

## GitBook Assets

### Images

- Drag and drop images directly in GitBook editor
- Images are automatically stored in `.gitbook/assets/`
- Reference with relative paths: `![Alt text](.gitbook/assets/image.png)`

### Files

- Upload files through GitBook interface
- Files are stored in `.gitbook/assets/`
- Link to files: `[Download file](.gitbook/assets/document.pdf)`

## Best Practices

### File Organization

```text
docs/
├── README.md              # Homepage
├── SUMMARY.md             # Table of contents
├── getting-started/       # Getting started section
│   ├── README.md          # Section overview
│   ├── installation.md    # Installation guide
│   └── quick-start.md     # Quick start guide
├── guides/                # User guides
│   ├── README.md
│   ├── basic-usage.md
│   └── advanced-usage.md
└── reference/             # Reference documentation
    ├── README.md
    ├── api-reference.md
    └── troubleshooting.md
```

### Naming Conventions

- Use lowercase filenames with hyphens: `user-guide.md`
- Folder names should be descriptive: `getting-started/`, `api-reference/`
- README.md files serve as section overviews

### Content Structure

1. **Start with overview**: Brief description of what the section covers
2. **Use clear headings**: Hierarchical structure with H1, H2, H3
3. **Include examples**: Code samples and practical examples
4. **Add cross-references**: Link to related sections
5. **Keep it scannable**: Use lists, tables, and visual elements

## Linking Between Pages

### Internal Links

```markdown
[Link to another page](../guides/user-guide.md)
[Link with anchor](./installation.md#requirements)
```

### Cross-References

```markdown
{% page-ref page="../guides/user-guide.md" %}
```

## SEO and Metadata

### Page Metadata

```markdown
---
description: Brief description for SEO
---

# Page Title
```

### Custom Headers

```markdown
---
title: Custom Page Title
description: Custom description
cover: .gitbook/assets/cover-image.png
---
```

## Troubleshooting Common Issues

### Sync Problems

1. **File conflicts**: Avoid editing the same file simultaneously in GitHub and GitBook
2. **Large files**: GitBook has file size limits for assets
3. **Special characters**: Avoid special characters in filenames
4. **Broken links**: Use relative paths and check links after sync

### Formatting Issues

1. **Code blocks**: Ensure proper language specification
2. **Tables**: Use proper markdown table syntax
3. **Lists**: Maintain consistent indentation
4. **Images**: Use appropriate alt text and sizing

This document serves as a quick reference for creating rich, interactive documentation in GitBook!
