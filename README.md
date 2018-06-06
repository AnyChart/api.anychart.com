# AnyChart API Reference 
### Overview

The AnyChart Technical Documentation Team welcomes you!

This repo contains source for [AnyChart JavaScript HTML5 Charts API Reference](//api.anychart.com) documentation.
We are appreciate your interest and will do our best to make AnyChart documentation as good as possible.  

If you have any suggestions how to improve this documentation, feel free to use one of the following methods:
* Create an issue in repo [issues tracker](//github.com/anychart/api-reference/issues), we will answer you in a 24 hours on weekdays and in 48 hours during weekends.
* [Fork](https://github.com/anychart/api-reference/fork) this repo, fix whatever you think needs fixing, and send us a pull request. Learn more about [github collaboration model](https://help.github.com/articles/using-pull-requests/).

### Documentation format
We use [JSDoc](http://usejsdoc.org/)-like formatting in [AnyChart API Reference](//api.anychart.com) pages, so the simple method doclet looks like this:
```
/**
 * Add callback for document ready event.<br/>
 * It is called when the DOM is ready, this can happen prior to images and 
 * other external content is loaded.
 * @param {Function} func Function which will called on document load event.
 * @param {*=} opt_scope Function call context.
 */
anychart.onDocumentReady;
```

Besides common JSDoc annotations, we use several custom annotations, here is the full list of them:

* `@ignoreDoc` - indicates that this doclet should be ignored when is HTML generated.
* `@example` - provide an absolute or relative path to a file with method.
* `@listing` - code sample with comments.
* `@detailed` - extended description of a doclet.





