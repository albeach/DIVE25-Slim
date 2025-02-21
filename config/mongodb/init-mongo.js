db.createUser({
    user: "mike",
    pwd: "Mike2025!",
    roles: [
        { role: "userAdminAnyDatabase", db: "admin" },
        { role: "readWriteAnyDatabase", db: "admin" }
    ]
});

db.createUser({
    user: "aubrey",
    pwd: "Aubrey2025!",
    roles: [
        { role: "userAdminAnyDatabase", db: "admin" },
        { role: "readWriteAnyDatabase", db: "admin" }
    ]
}); 