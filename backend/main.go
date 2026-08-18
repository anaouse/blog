package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"sort"
	"strings"
	"sync"

	"github.com/fsnotify/fsnotify"
	"github.com/gin-gonic/gin"
)

type Article struct {
	Title     string `json:"title"`
	CreatedAt string `json:"created_at"`
	Content   string `json:"content"`
}

type ArticleMeta struct {
	Slug      string `json:"slug"`
	Title     string `json:"title"`
	CreatedAt string `json:"created_at"`
}

func main() {
	// 启动时扫描一次文章元信息，之后由 fsnotify 增量更新
	index := make(map[string]ArticleMeta)
	var mu sync.RWMutex
	refreshIndex(&mu, &index)

	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		log.Fatal(err)
	}
	defer watcher.Close()
	if err := watcher.Add("articles"); err != nil {
		log.Printf("watch articles failed: %v", err)
	} else {
		go watchArticles(watcher, &mu, &index)
	}

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

	r.GET("/api/article_metainfo", func(c *gin.Context) {
		mu.RLock()
		metas := make([]ArticleMeta, 0, len(index))
		for slug, m := range index {
			metas = append(metas, ArticleMeta{Slug: slug, Title: m.Title, CreatedAt: m.CreatedAt})
		}
		mu.RUnlock()
		// 新文章在前
		sort.Slice(metas, func(i, j int) bool { return metas[i].CreatedAt > metas[j].CreatedAt })
		c.JSON(http.StatusOK, metas)
	})

	if err := r.Run(":6713"); err != nil {
		log.Fatal(err)
	}
}

// watchArticles 监控 articles 目录，目录内文件有增删改时整体重扫重建索引
func watchArticles(watcher *fsnotify.Watcher, mu *sync.RWMutex, index *map[string]ArticleMeta) {
	for {
		select {
		case event, ok := <-watcher.Events:
			if !ok {
				return
			}
			if event.Op&(fsnotify.Create|fsnotify.Write|fsnotify.Remove|fsnotify.Rename) != 0 {
				refreshIndex(mu, index)
			}
		case err, ok := <-watcher.Errors:
			if !ok {
				return
			}
			log.Printf("fsnotify error: %v", err)
		}
	}
}

// refreshIndex 扫描 articles/*.md 重建索引，覆盖新增/删除/更新三种状态
func refreshIndex(mu *sync.RWMutex, index *map[string]ArticleMeta) {
	entries, err := os.ReadDir("articles")
	if err != nil {
		log.Printf("scan articles failed: %v", err)
		return
	}

	newIndex := make(map[string]ArticleMeta, len(entries))
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".md") {
			continue
		}
		slug := strings.TrimSuffix(entry.Name(), ".md")
		article, err := loadArticle(slug)
		if err != nil {
			log.Printf("index article %s failed: %v", entry.Name(), err)
			continue
		}
		newIndex[slug] = ArticleMeta{Slug: slug, Title: article.Title, CreatedAt: article.CreatedAt}
	}

	mu.Lock()
	*index = newIndex
	mu.Unlock()
	log.Printf("articles index refreshed: %d articles", len(newIndex))
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
