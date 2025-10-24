Config = {}

Config.GovernmentJob = {
    name = 'government',
    minimumGrade = 4,
    society = 'society_government'
}

Config.SalaryLimits = {
    minimum = 0,
    maximum = 10000
}

Config.PayManagedJobs = {
    ambulance = {
        label = 'Ambulance',
        grades = {
            { grade = 0, label = 'Ambulance', salary = 4000 },
            { grade = 1, label = 'Ambulance Officer', salary = 3000 },
            { grade = 2, label = 'Pilot', salary = 4500 },
            { grade = 3, label = 'Specialist', salary = 4600 },
            { grade = 4, label = 'Doctor', salary = 4800 },
            { grade = 5, label = 'Chief Doctor', salary = 5000 },
            { grade = 6, label = 'Director of Hospital', salary = 5000 }
        }
    },
    police = {
        label = 'Rendőrség',
        grades = {
            { grade = 0, label = 'Kadét', salary = 4000 },
            { grade = 1, label = 'Járőr', salary = 3800 },
            { grade = 2, label = 'Járőr vezető', salary = 3500 },
            { grade = 3, label = 'Szolgálat parancsnok', salary = 4300 },
            { grade = 4, label = 'Osztályvezető', salary = 4600 },
            { grade = 5, label = 'Kapitányság vezető helyettes', salary = 4800 },
            { grade = 6, label = 'Kapitányság vezető', salary = 5000 }
        }
    },
    bcso = {
        label = 'BCSO',
        grades = {
            { grade = 0, label = 'Deputy', salary = 2000 },
            { grade = 1, label = 'Senior Deputy', salary = 2500 },
            { grade = 2, label = 'Corporal', salary = 3000 },
            { grade = 3, label = 'Sergeant', salary = 3500 },
            { grade = 4, label = 'Lieutenant', salary = 4000 },
            { grade = 5, label = 'Captain', salary = 4500 },
            { grade = 6, label = 'Area Commander', salary = 5000 },
            { grade = 7, label = 'Assistant Sheriff', salary = 5000 },
            { grade = 8, label = 'Sheriff', salary = 5000 }
        }
    },
    army = {
        label = 'Hadsereg',
        grades = {
            { grade = 0, label = 'Közkatona', salary = 20 },
            { grade = 1, label = 'Első osztályú közkatona', salary = 20 },
            { grade = 2, label = 'Tizedes', salary = 20 },
            { grade = 3, label = 'Őrmester', salary = 20 },
            { grade = 4, label = 'Törzsőrmester', salary = 20 },
            { grade = 5, label = 'Főtörzsőrmester', salary = 40 },
            { grade = 6, label = 'Szakaszvezető', salary = 40 },
            { grade = 7, label = 'Mesterőrmester', salary = 40 },
            { grade = 8, label = 'Törzszászlós', salary = 40 },
            { grade = 9, label = 'Főtörzszászlós', salary = 40 },
            { grade = 10, label = 'Hadnagy', salary = 40 },
            { grade = 11, label = 'Főhadnagy', salary = 40 },
            { grade = 12, label = 'Százados', salary = 40 },
            { grade = 13, label = 'Őrnagy', salary = 60 },
            { grade = 14, label = 'Alezredes', salary = 60 },
            { grade = 15, label = 'Ezredes', salary = 85 },
            { grade = 16, label = 'Dandártábornok', salary = 85 },
            { grade = 17, label = 'Vezérőrnagy', salary = 85 },
            { grade = 18, label = 'Altábornagy', salary = 85 },
            { grade = 19, label = 'Tábornok', salary = 100 },
            { grade = 20, label = 'Hadseregtábornok', salary = 100 }
        }
    },
    mechanic = {
        label = 'Szerelők',
        grades = {
            { grade = 0, label = 'Újonc', salary = 2500 },
            { grade = 1, label = 'Szerelő', salary = 3500 },
            { grade = 2, label = 'Irodavezető-helyettes', salary = 3000 },
            { grade = 3, label = 'Irodavezető', salary = 3000 },
            { grade = 4, label = 'Telepvezető-helyettes', salary = 5000 },
            { grade = 5, label = 'Telepvezető', salary = 5000 }
        }
    }
}

Config.StoreCategories = {
    auto_dealer = {
        label = 'Autó kereskedés',
        description = 'Általános jármű ár szorzója a kereskedésekhez.',
        multiplier = 1.0,
        minimum = 0.5,
        maximum = 3.0
    },
    general_store = {
        label = 'Bolt',
        description = 'Alapvető fogyasztási cikkek ár szorzója.',
        multiplier = 1.0,
        minimum = 0.5,
        maximum = 3.0
    },
    wages = {
        label = 'Fizetések adója',
        description = 'Globális fizetés levonás szorzó (0.0 - 1.5).',
        multiplier = 1.0,
        minimum = 0.0,
        maximum = 1.5
    }
}

Config.DailyAllocations = {
    ambulance = {
        label = 'Ambulance',
        amount = 20000
    },
    police = {
        label = 'Rendőrség',
        amount = 20000
    },
    bcso = {
        label = 'BCSO',
        amount = 20000
    },
    mechanic = {
        label = 'Szerelők',
        amount = 15000
    },
    army = {
        label = 'Hadsereg',
        amount = 25000
    }
}

Config.DefaultTax = {
    amount = 400,
    intervalMinutes = 120,
    label = 'Állami adó'
}

Config.AllocationIntervalMinutes = 1440

