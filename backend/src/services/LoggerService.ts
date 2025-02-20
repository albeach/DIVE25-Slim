export class LoggerService {
    private static instance: LoggerService;

    public static getInstance(): LoggerService {
        if (!LoggerService.instance) {
            LoggerService.instance = new LoggerService();
        }
        return LoggerService.instance;
    }

    public error(message: string, error?: any): void {
        console.error(message, error);
    }
}
