// /backend/src/services/OPAService.ts
import axios from 'axios';
import { LoggerService } from './LoggerService';
import { MetricsService } from './MetricsService';

interface UserAttributes {
    uniqueIdentifier: string;
    clearance: string;
    countryOfAffiliation: string;
    coiTags?: string[];
    lacvCode?: string;
    organizationalAffiliation?: string;
}

interface DocumentAttributes {
    clearance: string;
    releasableTo: string[];
    coiTags?: string[];
    lacvCode?: string;
}

export class OPAService {
    private static instance: OPAService;
    private readonly logger: LoggerService;
    private readonly metrics: MetricsService;
    private readonly opaUrl: string;

    private constructor() {
        this.logger = LoggerService.getInstance();
        this.metrics = MetricsService.getInstance();
        this.opaUrl = process.env.OPA_URL || 'http://opa:8181';
    }

    public static getInstance(): OPAService {
        if (!OPAService.instance) {
            OPAService.instance = new OPAService();
        }
        return OPAService.instance;
    }

    public async evaluateAccess(user: UserAttributes, document: DocumentAttributes): Promise<boolean> {
        const startTime = Date.now();
        try {
            const request = {
                input: {
                    user: {
                        uniqueIdentifier: user.uniqueIdentifier,
                        clearance: user.clearance,
                        countryOfAffiliation: user.countryOfAffiliation,
                        coiTags: user.coiTags || [],
                        lacvCode: user.lacvCode,
                        organizationalAffiliation: user.organizationalAffiliation
                    },
                    resource: {
                        clearance: document.clearance,
                        releasableTo: document.releasableTo,
                        coiTags: document.coiTags || [],
                        lacvCode: document.lacvCode
                    }
                }
            };

            const [accessPolicy, partnerPolicy] = await Promise.all([
                axios.post(`${this.opaUrl}/v1/data/access_policy/allow`, request),
                axios.post(`${this.opaUrl}/v1/data/dive25/partner_policies/allow`, request)
            ]);

            this.metrics.recordOPAEvaluation('access_check', Date.now() - startTime, true);

            return accessPolicy.data.result && partnerPolicy.data.result;

        } catch (error) {
            this.logger.error('OPA evaluation failed:', error);
            this.metrics.recordOPAError(error.message);
            return false;
        }
    }

    public async validateAttributes(attributes: UserAttributes): Promise<boolean> {
        try {
            const request = {
                input: {
                    user: attributes
                }
            };

            const response = await axios.post(
                `${this.opaUrl}/v1/data/access_policy/user_has_mandatory_attrs`,
                request
            );

            return response.data.result || false;
        } catch (error) {
            this.logger.error('Attribute validation failed:', error);
            return false;
        }
    }
}

export default OPAService.getInstance();