# -*- coding: utf-8 -*-
{
    "name": "Waste Pickup Request (LINE)",
    "summary": "Waste pickup requests and LINE integration helpers",
    "version": "0.2.1",
    "category": "Services",
    "license": "LGPL-3",
    "author": "Goodcan / Integration Team",
    "depends": ["base", "mail"],
    "data": [
        "security/security.xml",
        "security/ir.model.access.csv",
        "views/pickup_request_views.xml",
        "views/pickup_request_menu.xml",
        "views/pickup_change_request_views.xml",
    ],
    "application": True,
    "installable": True,
}
