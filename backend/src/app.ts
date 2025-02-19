private initializeRoutes(): void {
    // Existing routes...

    // Metrics endpoint for Prometheus to scrape
    this.app.get('/metrics', async (req: Request, res: Response) => {
        res.set('Content-Type', prometheus.register.contentType);
        res.end(await prometheus.register.metrics());
    });
}