import { LightningElement,api } from 'lwc';
export default class Ham_PaginationUtil extends LightningElement {

    @api totalRecords;
    @api pageSize;
    @api currentPage;
    @api resultLabel;
    @api isOverride = false;

    get wrapperClass() {
        return this.isOverride ? 'bottom-bar kirkland-override' : 'bottom-bar';
    }
    
    // Computed properties
    get showPagination() {
        return this.totalRecords > 0;
    }
    
    get totalPages() {
        return Math.ceil(this.totalRecords / this.pageSize);
    }
    
    get startCount() {
        return this.totalRecords === 0 ? 0 : ((this.currentPage - 1) * this.pageSize) + 1;
    }
    
    get endCount() {
        const end = this.currentPage * this.pageSize;
        return end > this.totalRecords ? this.totalRecords : end;
    }
    
    get recordsToSkip() {
        return (this.currentPage - 1) * this.pageSize;
    }
    
    get isFirstPage() {
        return this.currentPage === 1;
    }
    
    get isLastPage() {
        return this.currentPage === this.totalPages;
    }
    
    get firstPageClass() {
        return this.isFirstPage ? '' : 'page-btn';
    }
    
    get lastPageClass() {
        return this.isLastPage ? '' : 'page-btn';
    }
    
    get pages() {
        let pages = [];
        if (this.totalPages > 0) {
            const visiblePages = 4;
            let startPage = Math.max(1, this.currentPage - Math.floor(visiblePages / 2));
            let endPage = Math.min(this.totalPages, startPage + visiblePages - 1);
            
            // Adjust startPage if we're near the end
            if (endPage - startPage + 1 < visiblePages) {
                startPage = Math.max(1, endPage - visiblePages + 1);
            }
            
            // Add first page and ellipsis if needed
            if (startPage > 1) {
                pages.push({ number: 1, isCurrent: false, class: 'page-btn' });
                if (startPage > 2) {
                    pages.push({ number: '...', isCurrent: false, isEllipsis: true });
                }
            }
            
            // Add visible page range
            for (let i = startPage; i <= endPage; i++) {
                pages.push({
                    number: i,
                    isCurrent: i === this.currentPage,
                    class: i === this.currentPage ? 'page-btn active' : 'page-btn'
                });
            }
            
            // Add ellipsis and last page if needed
            if (endPage < this.totalPages) {
                if (endPage < this.totalPages - 1) {
                    pages.push({ number: '...', isCurrent: false, isEllipsis: true });
                }
                pages.push({ number: this.totalPages, isCurrent: false, class: 'page-btn' });
            }
        }
        return pages;
    }
    
    // Event handlers
    handlePageChange(event) {
        const pageNumber = Number(event.target.dataset.page);
        this.dispatchPaginationEvent(pageNumber);
    }
    
    handlePreviousPage() {
        if (!this.isFirstPage) {
            this.dispatchPaginationEvent(this.currentPage - 1);
        }
    }
    
    handleNextPage() {
        if (!this.isLastPage) {
            this.dispatchPaginationEvent(this.currentPage + 1);
        }
    }
    
    dispatchPaginationEvent(pageNumber) {
        const event = new CustomEvent('pagechange', {
            detail: {
                currentPage: pageNumber,
                recordsToSkip: (pageNumber - 1) * this.pageSize,
                pageSize: this.pageSize
            }
        });
        this.dispatchEvent(event);
    }
}