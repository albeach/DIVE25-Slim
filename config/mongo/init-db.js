// config/mongo/init-db.js

// Create collections with validation
db.createCollection("documents", {
    validator: {
        $jsonSchema: {
            bsonType: "object",
            required: ["title", "clearance", "metadata"],
            properties: {
                title: { bsonType: "string" },
                clearance: {
                    enum: ["UNCLASSIFIED", "RESTRICTED", "NATO CONFIDENTIAL",
                        "NATO SECRET", "COSMIC TOP SECRET"]
                },
                metadata: {
                    bsonType: "object",
                    required: ["createdAt", "createdBy"]
                }
            }
        }
    }
});

// Create indexes
db.documents.createIndex({ "metadata.createdAt": 1 });
db.documents.createIndex({ clearance: 1 });
db.documents.createIndex({ "metadata.createdBy": 1 });

// Create audit collection
db.createCollection("audit_logs", {
    capped: true,
    size: 5242880,
    max: 5000
});