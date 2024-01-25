//
//  InAppOrderingViewModel.swift
//  InAppOrdering
//
//  Created by Leandro Diaz on 10/23/23.
//

import SwiftUI
import CoreLocation
import MapKit

class InAppOrderingViewModel: ObservableObject {
    @ObservedObject var locationManager = LocationManager()
    @ObservedObject var cartModel = CartModel()
    let coreDataHander = CoreDataHandler.shared
    @Published var liveAddress = [LiveAddressModel]()
    @Published var nearbyStores = [LiveAddressModel]()
    @Published var selectedStore: StoreModel?
    @Published var selectedStores: [StoreModel] = []
    @Published var stores: [StoreModel] = []
    @Published var appMainTitle: String = "InAppOrdering"
    @Published var items: [MenuModel] = []
    @Published var favoriteStores: [StoreModel] = []
    @Published var currentSelectedStore: StoreModel?
    @Published var deliveryAddress: [LiveAddressModel] = []
    @Published var cartSubTotal: Double = 0.0
    @Published var cartItems: [MenuModel: Int] = [:]
    
    
    init() {
        //        self.removeAllFavorites()
       
        self.getCurrentLocation()
        self.getAllMenuItemsFromApi()
        self.searchDelivery(text: "5293", region: self.locationManager.region)
        print("Before accessing persistentContainer")
        print(coreDataHander)
        print("After accessing persistentContainer")
    }
    
    @Published var user = User(
        id: UUID(),
        firstName: "John",
        lastName: "Doe",
        email: "john.doe@example.com",
        profilePictureURL: nil,
        dateOfBirth: Date(),
        address: Address(
            company: "None",
            street: "123 Elm St",
            city: "Springfield",
            state: "IL",
            postalCode: "12345", distanceFromLocation: 0.0
        ),
        rewardsPoints: 1200
        
    )
    
    @Published var orderingOptions: [OrderingOption] = [OrderingOption(name: "Store Pickup", description: "Save time and skip the line. Order ahead and we'll have it ready when you arrive.", optionImage: "building", category: .inStorePickup),
                                                        OrderingOption(name: "Delivery", description: "Can't make it to the store? We'll have your order delivered right to your doorstep. \nPowered by DoorDash.", optionImage: "car", category: .delivery),
                                                        OrderingOption(name: "Catering", description: "Serve InAppOrdering Catering at your next event, Choose from favorites you know and love", optionImage: "bag", category: .catering)]
    
    @Published var buttonActions = [ActionButtons(name: "Fuel Up"), ActionButtons(name: "Start Order") ,ActionButtons(name: "Scan Card")]
    
    func items(in category: MenuModel.Category) -> [MenuModel] {
        return items.filter { $0.category == category }
    }
    
    // Function to get filtered menu items
    func getItems(forCategory category: MenuModel.Category) -> [MenuModel] {
          return self.items.filter {
              $0.category == category
          }
      }
    
//    func getItemsGroupedBySubcategory(forCategory category: MenuItem.Category) -> [MenuItem.Subcategory: [MenuItem]] {
//        var itemsGroupedBySubcategory: [MenuItem.Subcategory: [MenuItem]] = [:]
//
//            for subcategory in items.subcategories {
//                let filteredItems = self.items.filter {
//                    $0.category == category && ($0.category.subcategories.first(where: { $0 == subcategory }) != nil)
//                }
//                if !filteredItems.isEmpty {
//                    itemsGroupedBySubcategory[subcategory] = filteredItems
//                }
//            }
//            return itemsGroupedBySubcategory
//        }
    func getUniqueCategories() -> [MenuModel.Category] {
        let uniqueCategories = Set(items.map { $0.category })
        return Array(uniqueCategories)
    }
    
    func getSubcategoriesByCategory(category: MenuModel.Category) -> [MenuModel.Subcategory] {
        let itemsInCategory = items.filter({ $0.category == category })
        let subcategories = Set(itemsInCategory.map { $0.subCategory })
        return Array(subcategories)
    }
    
    func getByCategory(category: MenuModel.Category) -> [MenuModel] {
        print("by categor",
            items.filter({ $0.category == category })
        )
        
        return items.filter({ $0.category == category })
    }
    
    func getItemsBySubCategory(subCategory: MenuModel.Subcategory) -> [MenuModel] {
        print("by sub", items.filter({ $0.subCategory == subCategory }))
            let filteredItems = items.filter({ $0.subCategory == subCategory })
            return filteredItems
        }
    
    // MARK: - simulate get all menu items from an api
    func getAllMenuItemsFromApi() {
        self.items = InAppOrderingViewModel.menuItems
        let test = items.prefix(upTo: 4)
        for t in test {
            self.cartModel.addItem(t)
        }
//        self.cartItems = cartModel.items
//        self.cartSubTotal = cartModel.subTotal
    }
    
    
    // MARK: - GET CURRENT LOCATION
    private func getCurrentLocation() {
        locationManager.getCurrentLocation { success in
            switch success {
            case true:
                self.searchNearbyStores(near: self.locationManager.userLocation)
                self.favoriteStores = self.getFavoriteStores()
            case false:
                break
            }
        }
    }
    
    func searchNearbyStores(near location: CLLocation?) {
        guard let location = location else {
            print("We don't have a location yet")
            return
        }
        
        search(textQuery: "cvs", coordinates: location.coordinate)
    }
    
    // MARK:  -  Search functionality For address
    func search(text: String, region: MKCoordinateRegion) {
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = text
        searchRequest.region = region
        
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, _ in
            guard let response = response else {
                print("error")
                return
            }
            self.liveAddress = response.mapItems.map(LiveAddressModel.init)
                        print("pulling these address", self.liveAddress)
        }
    }
    
    func searchDelivery(text: String, region: MKCoordinateRegion) {
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = text
        searchRequest.region = region
        
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, _ in
            guard let response = response else {
                print("error")
                return
            }
            self.deliveryAddress = response.mapItems.map(LiveAddressModel.init)
            //            print("pulling these address", self.liveAddress)
        }
    }
    
    // MARK: - Default search for a radius 10 miles from current location
    func search(textQuery: String, coordinates: CLLocationCoordinate2D, radiusMileage: Double = 10) {
        // Create a region with a 10-mile radius around the user's location.
        let radiusMiles: CLLocationDistance = radiusMileage
        
        let region = MKCoordinateRegion(center: coordinates, latitudinalMeters: radiusMiles * 1609.34, longitudinalMeters: radiusMiles * 1609.34)
        
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = textQuery
        searchRequest.region = region
        
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, _ in
            guard let response = response else {
                print("Error searching for locations.")
                return
            }
            
            // MARK: Filter the results based on distance from the user's location.
            let filteredResults = response.mapItems.filter { item in
                let itemLocation = CLLocation(latitude: item.placemark.coordinate.latitude, longitude: item.placemark.coordinate.longitude)
                let userLocation = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
                let distance = userLocation.distance(from: itemLocation)
                
                let distanceKilometers = distance / 1000.0
                let distanceMiles = distanceKilometers / 1.60934 // Convert to miles
                print("Distance to \(item.name ?? "Unknown Location"): \(distanceMiles) miles")
                
                /// MARK: Filter addresses within a 10-mile radius (16093.44 meters).
                return distance < 16093.44
            }
            
            // MARK: Process the filtered results and create LiveAddressModel instances
            let filteredAddresses = filteredResults.map { item in
                let itemLocation = CLLocation(latitude: item.placemark.coordinate.latitude, longitude: item.placemark.coordinate.longitude)
                let userLocation = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
                let distance = userLocation.distance(from: itemLocation)
                
                let distanceKilometers = distance / 1000.0
                let distanceMiles = distanceKilometers / 1.60934 // Convert to miles
                
                return LiveAddressModel(mapItem: item, distance: distanceMiles)
            }
            
            self.nearbyStores = filteredAddresses
            //            print("Addresses within a 10-mile radius for query '\(textQuery)':", filteredAddresses)
            self.locationManager.stopUpdatingLocation()
            self.createNearByStores(liveAddress: filteredAddresses.sorted(by: {$0.distanceFromLocation ?? 0.0 < $1.distanceFromLocation ?? 0.0}))
        }
    }
    
    func createNearByStores(liveAddress: [LiveAddressModel]) {
        // Dictionary to keep track of last store number assigned for a zip code
        var zipToLastStoreNumber: [String: Int] = [:]
        
        liveAddress.forEach({ address in
            let baseStoreNumber = Int(address.zipCode) ?? 0
            let currentStoreNumber = (zipToLastStoreNumber[address.zipCode] ?? baseStoreNumber) + 1
            
            zipToLastStoreNumber[address.zipCode] = currentStoreNumber
            
            let newAddress = Address(company: address.company, street: address.street, city: address.city, state: address.state, postalCode: address.zipCode, distanceFromLocation: address.distanceFromLocation)
            let isFavorite = coreDataHander.isFavorite(storeNumber: currentStoreNumber)
            let newStore = StoreModel(name: address.company, storeNumber: currentStoreNumber, isFavorite: isFavorite, address: newAddress)
            self.stores.append(newStore)
        })
    }
    

    func getLocationFromAddress(_ address: String, completion: @escaping (CLLocationCoordinate2D?, Error?) -> Void) {
        let geocoder = CLGeocoder()
        
        geocoder.geocodeAddressString(address) { (placemarks, error) in
            guard let placemarks = placemarks, let location = placemarks.first?.location else {
                completion(nil, error)
                return
            }
            
            completion(location.coordinate, nil)
        }
    }
    
    func convertMileagesToString(mile: Double?) -> String? {
        if mile ?? 0.0 > 0 {
            return String(format: "%.1f", mile ?? 0.0) + "mi"
        }
        return ""
    }
    
    // MARK: - STORES FUNCTIONALITY
    
    // MARK: - Toggle a store's favorite status
    func toggleFavorite(store: StoreModel) {
        self.coreDataHander.toggleFavorite(store: store)

        if let index = stores.firstIndex(where: { $0.storeNumber == store.storeNumber }) {
            stores[index].isFavorite.toggle()
            print(store.isFavorite)
        }
        self.favoriteStores = self.getFavoriteStores()
    }
    
    // MARK: - Check if a store is a favorite
    func isFavorite(store: StoreModel) -> Bool {
       return self.coreDataHander.isFavorite(storeNumber: store.storeNumber)
    }
    
    // MARK: - Remove all favorite stores
    private func removeAllFavorites() {
        self.coreDataHander.removeAllFavorites()
        print("Removed all favorite stores")
    }
    
    // MARK: - Get all favorite stores references
    func getFavoriteStores() -> [StoreModel] {
        return self.coreDataHander.getAllFavoriteStores()
    }
}

// MARK: Cart Functionality
extension InAppOrderingViewModel {
    func addToCart(item: MenuModel) {
        if isItemInCart(item: item) {
            if var quantity = cartModel.items[item] {
                quantity += 1
                updateQuantity(for: item, quantity: quantity)
            }
        } else {
            cartModel.addItem(item)
        }
    }

    func isItemInCart(item: MenuModel) -> Bool {
        cartModel.isItemInCart(item)
    }
    
    func removeItem(_ item: MenuModel) {
        if let quantity = cartItems[item], quantity > 1 {
            cartItems[item] = quantity - 1
        } else {
            cartItems.removeValue(forKey: item)
        }
        cartModel.items = cartItems
        updateTotal()
    }
    
    func updateQuantity(for item: MenuModel, quantity: Int) {
        cartModel.items[item] = quantity
        updateTotal()
    }
    
    // Method to calculate the total
    private func updateTotal() {
        let newTotal = cartModel.items.reduce(0) { sum, pair in
            let (item, quantity) = pair
            return sum + (item.price * Double(quantity))
        }
        print(newTotal)
        cartModel.subTotal = newTotal
        self.cartSubTotal = cartModel.subTotal
        
        cartModel.setSubTotal()
    }
    
    var cartSubtotal: Double {
        cartModel.items.reduce(0) { sum, item in
            sum + (item.key.price * Double(item.value))
        }
    }
    
    var cartTax: Double {
        cartSubtotal * 0.07 // 7% tax
    }
    
    var cartTotal: Double {
        cartSubtotal + cartTax
    }
}

extension InAppOrderingViewModel {
    static let menuItems: [MenuModel] = [
        
        // STARTERS
        MenuModel(name: "Mediterranean Olive Tapenade", description: "Olive mix, garlic, capers, and fresh herbs. Served with warm pita bread.", imageName: "mediterraneanOliveTapenade", price: 7.99, category: startersCategory, subCategory: .salads),
        MenuModel(name: "Crispy Calamari Rings", description: "Lightly breaded calamari, deep-fried to perfection. Accompanied by a tangy aioli dip.", imageName: "crispyCalamariRings", price: 9.50, category: startersCategory, subCategory: .calamari),
        
        MenuModel(
            name: "Breakfast Plate",
            description: "A hearty breakfast plate that's sure to kickstart your day. Fluffy scrambled eggs are paired with crispy bacon strips. A piece of toast offers a crunchy contrast, and a side of fresh fruit salad adds a refreshing touch.",
            imageName: "breakfastPlate",
            price: 12.99,
            category: startersCategory, subCategory: .salads
        ),
        
        MenuModel(
            name: "Gourmet Salad Plate",
            description: "A refreshing plate featuring a gourmet salad with mixed greens, cherry tomatoes, and feta cheese. Drizzled with a light vinaigrette dressing, it's the perfect appetizer to start your meal.",
            imageName: "gourmetSaladPlate",
            price: 9.99,
            category: startersCategory, subCategory: .salads
        ),
        MenuModel(
            name: "Sushi Plate",
            description: "A meticulously arranged plate featuring an assortment of fresh nigiri and sashimi. The vibrant colors of the fish contrast beautifully with the white rice. A side of wasabi and ginger garnish complements the sushi, adding a touch of spice and tang.",
            imageName: "sushiPlate",
            price: 18.99,
            category: startersCategory, subCategory: .sushi
        ),
        
        
        // MAIN COURSE
        MenuModel(name: "Seared Atlantic Salmon", description: "Fresh salmon fillet with a lemon herb crust. Served with asparagus and garlic mashed potatoes.", imageName: "searedAtlanticSalmon", price: 18.99, category: mainCourseCategory, subCategory: .seafood),
        
        MenuModel(
            name: "Vegetarian Curry Plate",
            description: "An appetizing plate showcasing a hearty vegetarian curry made of mixed vegetables. The curry is accompanied by a side of fluffy basmati rice, offering a delightful combination of flavors and textures.",
            imageName: "vegetarianCurryPlate",
            price: 14.99,
            category: mainCourseCategory, subCategory: .salads
        ),
        MenuModel(
            name: "Savory Steak Plate",
            description: "A mouth-watering plate showcasing a perfectly grilled steak, accompanied by grilled vegetables and a side of creamy mashed potatoes topped with rich gravy.",
            imageName: "savorySteakPlate",
            price: 24.99,
            category: mainCourseCategory, subCategory: .steak
        ),
        
        MenuModel(
            name: "Seafood Plate",
            description: "A delightful plate filled with fresh seafood. Featuring grilled shrimp and lemon slices, it's served with a side of buttery garlic rice, capturing the essence of the ocean.",
            imageName: "seafoodPlate",
            price: 21.99,
            category: mainCourseCategory, subCategory: .seafood
        ),
        
        MenuModel(
            name: "Pasta Plate",
            description: "A classic Italian plate presenting spaghetti aglio e olio. Garnished with fresh basil and sprinkled with grated parmesan, it's a pasta lover's dream.",
            imageName: "pastaPlate",
            price: 16.99,
            category: mainCourseCategory, subCategory: .pasta
        ),
        
        // DESERTS
        
        MenuModel(name: "Tuscan Chicken Pasta", description: "Grilled chicken tossed in a creamy sun-dried tomato sauce with penne pasta. Topped with Parmesan and fresh basil.", imageName: "tuscanChickenPasta", price: 16.50, category: mainCourseCategory, subCategory: .pasta),
        MenuModel(name: "Chocolate Lava Cake", description: "Decadent chocolate cake with a molten center. Paired with a scoop of vanilla ice cream.", imageName: "chocolateLavaCake", price: 8.50, category: dessertsCategory, subCategory: .cakes),
        MenuModel(name: "Mango Panna Cotta", description: "Silky smooth Italian dessert with a tropical twist. Topped with fresh mango chunks.", imageName: "mangoPannaCotta", price: 7.99, category: dessertsCategory, subCategory: .pannaCotta),
        
        MenuModel(
            name: "Dessert Plate",
            description: "A delectable dessert plate presenting a slice of rich chocolate cake that's moist and dense. Fresh berries add a burst of freshness, while a scoop of creamy vanilla ice cream melts alongside, creating a heavenly trio.",
            imageName: "dessertPlate",
            price: 10.99,
            category: dessertsCategory, subCategory: .cakes
        ),
        
        
        // DRINKS
        MenuModel(name: "Classic Cappuccino", description: "Rich and bold espresso topped with steamed milk foam.", imageName: "cappuccino", price: 3.50, category: drinks, subCategory: .hotBeverages, subSubCategory: .hotCoffee),

        // Hot Beverages
        MenuModel(name: "Green Tea", description: "Freshly brewed green tea, known for its soothing and refreshing qualities.", imageName: "greenTea", price: 2.50, category: drinks, subCategory: .hotBeverages),
        
        // Macchiatos
        MenuModel(name: "Caramel Macchiato", description: "Espresso mixed with vanilla and caramel, topped with milk foam.", imageName: "caramelMacchiato", price: 4.00, category: drinks, subCategory: .hotBeverages),
        MenuModel(name: "Hazelnut Macchiato", description: "A delightful blend of espresso, steamed milk, and rich hazelnut flavor.", imageName: "hazelnutMacchiato", price: 4.25, category: drinks, subCategory: .hotBeverages),
        
        // Ice Beverages
        MenuModel(name: "Iced Americano", description: "A classic, refreshing espresso drink with water and ice.", imageName: "icedAmericano", price: 2.99, category: drinks, subCategory: .iceBeverages),
        MenuModel(name: "Cold Brew Coffee", description: "Smooth, cold-brewed coffee served over ice.", imageName: "coldBrewCoffee", price: 3.75, category: drinks, subCategory: .iceBeverages),
        
        // Smoothies
        MenuModel(name: "Strawberry Banana Smoothie", description: "A sweet blend of strawberries and bananas, perfect for a nutritious boost.", imageName: "strawberryBananaSmoothie", price: 4.50, category: drinks, subCategory: .smoothies),
        MenuModel(name: "Mango Pineapple Smoothie", description: "Tropical mango and pineapple pureed into a refreshing smoothie.", imageName: "mangoPineappleSmoothie", price: 4.75, category: drinks, subCategory: .smoothies),
        
        // Milkshakes
        MenuModel(name: "Classic Vanilla Milkshake", description: "Creamy milkshake made with real vanilla ice cream and milk.", imageName: "vanillaMilkshake", price: 4.00, category: drinks, subCategory: .milkshakes),
        MenuModel(name: "Oreo Milkshake", description: "Rich and creamy milkshake blended with Oreo cookies.", imageName: "oreoMilkshake", price: 4.50, category: drinks, subCategory: .milkshakes),
        
        // Frozen Beverages
        MenuModel(name: "Frozen Lemonade", description: "A sweet and tangy frozen treat, perfect for hot days.", imageName: "frozenLemonade", price: 3.50, category: drinks, subCategory: .frozenBeverages),
        MenuModel(name: "Frozen Margarita", description: "Refreshing blend of tequila, lime, and crushed ice.", imageName: "frozenMargarita", price: 6.00, category: drinks, subCategory: .frozenBeverages)
    ]
    
    static let drinks =  MenuModel.Category.drinks//  Category(name: "Drinks", subcategories: [.hotBeverages, .macchiatos, .iceBeverages, .smoothies, .milkshake, .frozenBeverages])
    static let startersCategory = MenuModel.Category.starters //Category(name: "Starters", subcategories: [.tapenades, .calamari, .sushi, .salads])
    static let mainCourseCategory = MenuModel.Category.mainCourse// Category(name: "Main Course", subcategories: [.vegetarian, .steak, .seafood, .pasta])
    static let dessertsCategory = MenuModel.Category.desserts // Category(name: "Desserts", subcategories: [.cakes, .pannaCotta, .iceCream])
    
   
}


//class StoreManager {
//    private let favoriteStoresKey = "favoriteStores"
//
//    // Toggle a store's favorite status
//    func toggleFavorite(store: StoreModel) {
//        if isFavorite(store: store) {
//            removeFavorite(store: store)
//        } else {
//            saveFavorite(store: store)
//        }
//    }
//
//    // Check if a store is a favorite
//    func isFavorite(store: StoreModel) -> Bool {
//        let favorites = getFavoriteStores()
//        return favorites.contains(where: { $0.storeNumber == store.storeNumber })
//    }
//
//    // Save a store to favorites
//    private func saveFavorite(store: StoreModel) {
//        var favorites = getFavoriteStores()
//        let favorite = Favorite(storeNumber: store.storeNumber)
//        favorites.append(favorite)
//
//        if let data = try? JSONEncoder().encode(favorites) {
//            UserDefaults.standard.setValue(data, forKey: favoriteStoresKey)
//        }
//    }
//
//    // Remove a store from favorites
//    private func removeFavorite(store: StoreModel) {
//        var favorites = getFavoriteStores()
//        favorites.removeAll { $0.storeNumber == store.storeNumber }
//
//        if let data = try? JSONEncoder().encode(favorites) {
//            UserDefaults.standard.setValue(data, forKey: favoriteStoresKey)
//        }
//    }
//
//    // Get all favorite stores references
//    func getFavoriteStores() -> [Favorite] {
//        if let data = UserDefaults.standard.data(forKey: favoriteStoresKey),
//           let favorites = try? JSONDecoder().decode([Favorite].self, from: data) {
//            return favorites
//        }
//        return []
//    }
//}
