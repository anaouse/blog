package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/gin-gonic/gin"
)

type Article struct {
	Title     string `json:"title"`
	CreatedAt string `json:"created_at"`
	Content   string `json:"content"`
}

func main() {
	r := gin.Default()

	r.GET("/api/hello", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"message": "hello world"})
	})

	r.GET("/api/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	r.GET("/api/articles/:slug", func(c *gin.Context) {
		article, err := loadArticle(c.Param("slug"))
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, article)
	})

	if err := r.Run(":6713"); err != nil {
		log.Fatal(err)
	}
}

// loadArticle 从 articles/{slug}.md 读取文章
func loadArticle(slug string) (Article, error) {
	data, err := os.ReadFile("articles/" + slug + ".md")
	if err != nil {
		return Article{}, fmt.Errorf("article not found")
	}
	return parseArticle(data)
}

// parseArticle 解析 frontmatter（--- 包裹的 YAML 键值对）和正文
func parseArticle(data []byte) (Article, error) {
	raw := strings.ReplaceAll(string(data), "\r\n", "\n")
	if !strings.HasPrefix(raw, "---\n") {
		return Article{}, fmt.Errorf("invalid article: missing frontmatter")
	}

	rest := raw[len("---\n"):]
	end := strings.Index(rest, "\n---\n")
	if end < 0 {
		return Article{}, fmt.Errorf("invalid article: missing frontmatter end")
	}
	fm := rest[:end]
	content := strings.TrimPrefix(rest[end+len("\n---\n"):], "\n")

	article := Article{Content: content}
	for _, line := range strings.Split(fm, "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		key, value, ok := strings.Cut(line, ":")
		if !ok {
			continue
		}
		value = strings.Trim(strings.TrimSpace(value), `"`)
		switch strings.TrimSpace(key) {
		case "title":
			article.Title = value
		case "created_at":
			article.CreatedAt = value
		}
	}
	if article.Title == "" {
		return Article{}, fmt.Errorf("invalid article: missing title")
	}
	return article, nil
}
