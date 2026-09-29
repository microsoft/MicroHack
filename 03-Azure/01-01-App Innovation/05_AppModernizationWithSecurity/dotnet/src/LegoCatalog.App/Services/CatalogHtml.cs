using System.Text.Encodings.Web;
using LegoCatalog.App.Models;

namespace LegoCatalog.App.Services;

/// <summary>
/// Renders the stable server-side detail contract for direct HTTP requests.
/// </summary>
public static class CatalogHtml
{
    public static string RenderDetail(LegoFigure figure)
    {
        Func<string, string> encode = HtmlEncoder.Default.Encode;
        var id = figure.Id.ToString("D");
        var name = encode(figure.Name);
        var description = encode(figure.Description);
        var categoryName = encode(figure.Category!.Name);
        var categorySlug = encode(figure.Category.Slug);
        var filename = encode(figure.ImageFile);
        return $$"""
            <!DOCTYPE html>
            <html lang="en">
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1">
              <title>{{name}} - Lego Catalog</title>
              <link rel="stylesheet" href="/css/site.css">
            </head>
            <body>
              <main class="content">
                <article class="figure-detail"
                         data-figure-detail="{{id}}"
                         data-figure-id="{{id}}"
                         data-figure-name="{{name}}"
                         data-figure-description="{{description}}"
                         data-category-name="{{categoryName}}"
                         data-category-slug="{{categorySlug}}"
                         data-image-filename="{{filename}}">
                  <div class="media"><img src="/images/{{filename}}" alt="{{name}}"></div>
                  <div class="info">
                    <h1>{{name}}</h1>
                    <div class="badge large">{{categoryName}}</div>
                    <p class="description">{{description}}</p>
                    <a class="btn" href="/">Back</a>
                  </div>
                </article>
              </main>
            </body>
            </html>
            """;
    }
}
